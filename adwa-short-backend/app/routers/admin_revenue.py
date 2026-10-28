from __future__ import annotations

import json
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.deps import get_current_super_admin
from app.models.content import Episode, Series
from app.models.revenue import Creator, Payout, RevenueTransaction
from app.models.user import User
from app.schemas.revenue import (
    PlatformTreasuryOut,
    ProcessExpiredResult,
    RevenueByContentRow,
    RevenueByCreatorRow,
    RevenueByMethodRow,
    RevenueOverview,
    RevenueTransactionOut,
)
from app.services.cbe_gateway import cbe_gateway
from app.services.revenue import check_expired_passes
from app.utils.time import utcnow

router = APIRouter(prefix="/admin/revenue", tags=["admin-revenue"])


@router.get("/overview", response_model=RevenueOverview)
async def revenue_overview(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    gross_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0))
    )
    gross = float(gross_res.scalar_one() or 0)
    creator_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0))
    )
    creator_share = float(creator_res.scalar_one() or 0)
    platform_share = gross - creator_share

    paid_res = await db.execute(
        select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
            Payout.status.in_(("processed", "pending"))
        )
    )
    paid_out = float(paid_res.scalar_one() or 0)

    pending_res = await db.execute(
        select(
            RevenueTransaction.creator_id,
            func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0).label("share"),
        )
        .where(RevenueTransaction.creator_id.is_not(None))
        .group_by(RevenueTransaction.creator_id)
    )
    pending_by_creator: dict[int, float] = {}
    for cid, share in pending_res.all():
        pending_by_creator[int(cid)] = float(share or 0)

    paid_by_creator_res = await db.execute(
        select(
            Payout.creator_id,
            func.coalesce(func.sum(Payout.amount_birr), 0).label("paid"),
        )
        .where(Payout.status.in_(("processed", "pending")))
        .group_by(Payout.creator_id)
    )
    for cid, paid in paid_by_creator_res.all():
        cid = int(cid)
        pending_by_creator[cid] = max(pending_by_creator.get(cid, 0.0) - float(paid or 0), 0.0)
    total_pending = sum(pending_by_creator.values())

    count_res = await db.execute(select(func.count(RevenueTransaction.id)))
    total_count = int(count_res.scalar_one() or 0)

    return RevenueOverview(
        total_gross_birr=gross,
        total_platform_share_birr=platform_share,
        total_creator_share_birr=creator_share,
        total_paid_out_birr=paid_out,
        total_pending_balance_birr=total_pending,
        transaction_count=total_count,
        treasury_account_number=settings.CBE_TREASURY_ACCOUNT_NUMBER,
        treasury_account_name=settings.CBE_TREASURY_ACCOUNT_NAME,
        treasury_bank_name=settings.CBE_TREASURY_BANK_NAME,
        treasury_balance_birr=round(platform_share, 2),
    )


@router.get("/by-creator", response_model=List[RevenueByCreatorRow])
async def revenue_by_creator(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(
            RevenueTransaction.creator_id,
            Creator.name.label("creator_name"),
            func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0).label("gross"),
            func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0).label("creator_share"),
            func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0).label("platform_share"),
        )
        .select_from(RevenueTransaction)
        .join(Creator, Creator.id == RevenueTransaction.creator_id, isouter=True)
        .group_by(RevenueTransaction.creator_id, Creator.name)
        .order_by(desc("gross"))
    )
    rows = res.all()
    out: List[RevenueByCreatorRow] = []
    for cid, name, gross, creator_share, platform_share in rows:
        pending = float(creator_share or 0)
        if cid is not None:
            paid_res = await db.execute(
                select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
                    Payout.creator_id == cid,
                    Payout.status.in_(("processed", "pending")),
                )
            )
            pending = max(pending - float(paid_res.scalar_one() or 0), 0.0)
        out.append(
            RevenueByCreatorRow(
                creator_id=int(cid) if cid is not None else None,
                creator_name=name,
                gross_birr=float(gross or 0),
                creator_share_birr=float(creator_share or 0),
                platform_share_birr=float(platform_share or 0),
                pending_balance_birr=pending,
            )
        )
    return out


@router.get("/by-content", response_model=List[RevenueByContentRow])
async def revenue_by_content(
    creator_id: Optional[int] = Query(default=None),
    series_id: Optional[int] = Query(default=None),
    limit: int = Query(default=100, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    stmt = (
        select(
            RevenueTransaction.series_id,
            RevenueTransaction.episode_id,
            func.coalesce(RevenueTransaction.creator_id, Episode.creator_id, Series.creator_id).label("creator_id"),
            func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0).label("gross"),
            func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0).label("creator_share"),
            func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0).label("platform_share"),
        )
        .select_from(RevenueTransaction)
        .join(Episode, Episode.id == RevenueTransaction.episode_id, isouter=True)
        .join(Series, Series.id == func.coalesce(RevenueTransaction.series_id, Episode.series_id), isouter=True)
    )
    if creator_id is not None:
        stmt = stmt.where(
            or_(
                RevenueTransaction.creator_id == creator_id,
                Episode.creator_id == creator_id,
                Series.creator_id == creator_id,
            )
        )
    if series_id is not None:
        stmt = stmt.where(
            or_(
                RevenueTransaction.series_id == series_id,
                Episode.series_id == series_id,
            )
        )
    stmt = (
        stmt.group_by(
            RevenueTransaction.series_id,
            RevenueTransaction.episode_id,
            func.coalesce(RevenueTransaction.creator_id, Episode.creator_id, Series.creator_id),
        )
        .order_by(desc("gross"))
        .limit(limit)
    )
    res = await db.execute(stmt)

    creators_res = await db.execute(select(Creator))
    creators_map = {c.id: (c.display_name or c.name) for c in creators_res.scalars().all()}

    series_res = await db.execute(select(Series))
    series_map = {s.id: s for s in series_res.scalars().all()}

    episodes_res = await db.execute(select(Episode))
    episodes_map = {e.id: e for e in episodes_res.scalars().all()}

    out: List[RevenueByContentRow] = []
    for sid, eid, cid, gross, creator_share, platform_share in res.all():
        title = "Unknown"
        series_title = None
        content_type = "series"

        resolved_cid = cid
        resolved_sid = sid

        if eid is not None:
            content_type = "episode"
            ep = episodes_map.get(eid)
            if ep is not None:
                title = f"Ep #{ep.episode_number}: {ep.title}"
                resolved_sid = ep.series_id
                if not resolved_cid and ep.creator_id:
                    resolved_cid = ep.creator_id
            ser = series_map.get(resolved_sid) if resolved_sid else None
            if ser is not None:
                series_title = ser.title
                if not resolved_cid and ser.creator_id:
                    resolved_cid = ser.creator_id
        elif resolved_sid is not None:
            content_type = "series"
            ser = series_map.get(resolved_sid)
            if ser is not None:
                title = ser.title
                series_title = ser.title
                if not resolved_cid and ser.creator_id:
                    resolved_cid = ser.creator_id

        creator_name = creators_map.get(resolved_cid) if resolved_cid else None

        out.append(
            RevenueByContentRow(
                series_id=resolved_sid,
                episode_id=eid,
                creator_id=resolved_cid,
                creator_name=creator_name,
                series_title=series_title,
                title=title,
                content_type=content_type,
                gross_birr=float(gross or 0),
                creator_share_birr=float(creator_share or 0),
                platform_share_birr=float(platform_share or 0),
            )
        )
    return out


@router.get("/by-method", response_model=List[RevenueByMethodRow])
async def revenue_by_method(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(
            RevenueTransaction.source_type,
            func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0).label("gross"),
            func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0).label("creator_share"),
            func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0).label("platform_share"),
            func.count(RevenueTransaction.id).label("cnt"),
        )
        .group_by(RevenueTransaction.source_type)
        .order_by(desc("gross"))
    )
    out: List[RevenueByMethodRow] = []
    for src, gross, creator_share, platform_share, cnt in res.all():
        out.append(
            RevenueByMethodRow(
                source_type=src,
                gross_birr=float(gross or 0),
                creator_share_birr=float(creator_share or 0),
                platform_share_birr=float(platform_share or 0),
                transaction_count=int(cnt or 0),
            )
        )
    return out


@router.get("/transactions", response_model=List[RevenueTransactionOut])
async def list_transactions(
    creator_id: Optional[int] = None,
    source_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    stmt = select(RevenueTransaction)
    if creator_id is not None:
        stmt = stmt.where(RevenueTransaction.creator_id == creator_id)
    if source_type is not None:
        stmt = stmt.where(RevenueTransaction.source_type == source_type)
    if start_date is not None:
        stmt = stmt.where(RevenueTransaction.created_at >= start_date)
    if end_date is not None:
        stmt = stmt.where(RevenueTransaction.created_at <= end_date)
    stmt = stmt.order_by(desc(RevenueTransaction.created_at)).limit(limit).offset((page - 1) * limit)
    res = await db.execute(stmt)
    return list(res.scalars().all())


@router.post("/process-expired", response_model=ProcessExpiredResult)
async def process_expired(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    result = await check_expired_passes(db)
    await db.commit()
    return ProcessExpiredResult(**result)


@router.get("/treasury", response_model=PlatformTreasuryOut)
async def platform_treasury_status(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    """Returns official Commercial Bank of Ethiopia (CBE) Platform Treasury balance and institutional ledger."""
    # 1. Total Platform & Creator Shares
    gross_res = await db.execute(select(func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0)))
    gross = float(gross_res.scalar_one() or 0)

    creator_res = await db.execute(select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0)))
    creator_share = float(creator_res.scalar_one() or 0)
    platform_share = gross - creator_share

    # 2. Payouts disbursed vs pending
    paid_res = await db.execute(
        select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
            Payout.status.in_(("processed", "completed"))
        )
    )
    paid_out = float(paid_res.scalar_one() or 0)

    # 3. Breakdown of platform-owned retained revenues
    sub_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0)).where(
            RevenueTransaction.source_type.in_(("subscription_consumption", "unconsumed_subscription", "cbe_subscription"))
        )
    )
    sub_retained = float(sub_res.scalar_one() or 0)

    unconsumed_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0)).where(
            RevenueTransaction.source_type.in_(("unconsumed_pass", "unconsumed_subscription"))
        )
    )
    unconsumed_retained = float(unconsumed_res.scalar_one() or 0)

    ad_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0)).where(
            RevenueTransaction.source_type == "ad_revenue"
        )
    )
    ad_retained = float(ad_res.scalar_one() or 0)

    split_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0)).where(
            RevenueTransaction.source_type.in_(("coin_payment", "pass_consumption", "subscription_consumption"))
        )
    )
    split_retained = float(split_res.scalar_one() or 0)

    pending_balance = max(creator_share - paid_out, 0.0)

    return PlatformTreasuryOut(
        treasury_account_number=settings.CBE_TREASURY_ACCOUNT_NUMBER,
        treasury_account_name=settings.CBE_TREASURY_ACCOUNT_NAME,
        treasury_bank_name=settings.CBE_TREASURY_BANK_NAME,
        treasury_branch=settings.CBE_TREASURY_BRANCH,
        total_platform_revenue_birr=round(platform_share, 2),
        total_creator_earnings_birr=round(creator_share, 2),
        total_creator_disbursed_birr=round(paid_out, 2),
        total_creator_payable_birr=round(pending_balance, 2),
        treasury_retained_balance_birr=round(platform_share, 2),
        subscriptions_retained_birr=round(sub_retained, 2),
        unconsumed_passes_retained_birr=round(unconsumed_retained, 2),
        ad_revenues_retained_birr=round(ad_retained, 2),
        content_split_fees_retained_birr=round(split_retained, 2),
    )


@router.get("/payouts", response_model=List[dict])
async def list_all_payouts(
    creator_id: Optional[int] = None,
    status_filter: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    stmt = (
        select(Payout, Creator.name.label("creator_name"))
        .join(Creator, Creator.id == Payout.creator_id, isouter=True)
    )
    if creator_id is not None:
        stmt = stmt.where(Payout.creator_id == creator_id)
    if status_filter:
        stmt = stmt.where(Payout.status == status_filter)
    stmt = stmt.order_by(desc(Payout.created_at)).limit(limit)
    res = await db.execute(stmt)
    out = []
    for p, cname in res.all():
        out.append({
            "id": p.id,
            "creator_id": p.creator_id,
            "creator_name": cname or f"Creator #{p.creator_id}",
            "amount_birr": float(p.amount_birr),
            "status": p.status,
            "processed_at": p.processed_at.isoformat() if p.processed_at else None,
            "processed_by_admin_id": p.processed_by_admin_id,
            "reference": p.reference,
            "cbe_transaction_id": p.cbe_transaction_id,
            "bank_account_number": p.bank_account_number,
            "bank_account_name": p.bank_account_name,
            "bank_name": p.bank_name,
            "cbe_payout_status": p.cbe_payout_status,
            "treasury_account_number": p.treasury_account_number or settings.CBE_TREASURY_ACCOUNT_NUMBER,
            "notes": p.notes,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        })
    return out


@router.post("/payouts/{payout_id}/disburse")
async def disburse_pending_payout(
    payout_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    """Super Admin manual trigger or retry to disburse a payout via Commercial Bank of Ethiopia (CBE) B2C."""
    p_res = await db.execute(select(Payout).where(Payout.id == payout_id))
    payout = p_res.scalar_one_or_none()
    if not payout:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payout not found")

    c_res = await db.execute(select(Creator).where(Creator.id == payout.creator_id))
    creator = c_res.scalar_one_or_none()

    acc_num = payout.bank_account_number or (creator.bank_account_number if creator else None)
    acc_name = payout.bank_account_name or (creator.bank_account_name if creator else (creator.name if creator else "Creator"))
    b_name = payout.bank_name or (creator.bank_name if creator and creator.bank_name else settings.CBE_TREASURY_BANK_NAME)

    if not acc_num:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Creator has no registered Commercial Bank of Ethiopia (CBE) account number",
        )

    disburse_res = await cbe_gateway.disburse_creator_payout(
        payout_id=payout.id,
        creator_id=payout.creator_id,
        amount_birr=float(payout.amount_birr),
        bank_account_number=acc_num,
        bank_account_name=acc_name,
        bank_name=b_name,
    )
    payout.cbe_transaction_id = disburse_res.get("cbe_transaction_id")
    payout.status = "processed" if disburse_res.get("status") == "completed" else disburse_res.get("status", "pending")
    payout.cbe_payout_status = disburse_res.get("status", "completed")
    payout.reference = f"cbe:b2c:{payout.cbe_transaction_id}"
    payout.bank_account_number = acc_num
    payout.bank_account_name = acc_name
    payout.bank_name = b_name
    payout.treasury_account_number = settings.CBE_TREASURY_ACCOUNT_NUMBER
    payout.processed_at = utcnow()
    payout.processed_by_admin_id = admin.id
    payout.cbe_response_payload = json.dumps(disburse_res)
    await db.commit()
    await db.refresh(payout)
    return {
        "status": "success",
        "message": f"Successfully disbursed ETB {payout.amount_birr} to CBE account {acc_num}",
        "payout_id": payout.id,
        "cbe_transaction_id": payout.cbe_transaction_id,
    }
