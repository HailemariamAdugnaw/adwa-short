from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin
from app.models.content import Episode, Series
from app.models.revenue import Creator, Payout, RevenueTransaction
from app.models.user import User
from app.schemas.revenue import (
    ProcessExpiredResult,
    RevenueByContentRow,
    RevenueByCreatorRow,
    RevenueByMethodRow,
    RevenueOverview,
    RevenueTransactionOut,
)
from app.services.revenue import check_expired_passes

router = APIRouter(prefix="/admin/revenue", tags=["admin-revenue"])


@router.get("/overview", response_model=RevenueOverview)
async def revenue_overview(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
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
    )


@router.get("/by-creator", response_model=List[RevenueByCreatorRow])
async def revenue_by_creator(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
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
    limit: int = Query(default=50, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(
        select(
            RevenueTransaction.series_id,
            RevenueTransaction.episode_id,
            func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0).label("gross"),
            func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0).label("creator_share"),
            func.coalesce(func.sum(RevenueTransaction.platform_share_birr), 0).label("platform_share"),
        )
        .group_by(RevenueTransaction.series_id, RevenueTransaction.episode_id)
        .order_by(desc("gross"))
        .limit(limit)
    )
    out: List[RevenueByContentRow] = []
    for sid, eid, gross, creator_share, platform_share in res.all():
        title = "Unknown"
        if eid is not None:
            er = await db.execute(select(Episode).where(Episode.id == eid))
            ep = er.scalar_one_or_none()
            if ep is not None:
                title = ep.title
        elif sid is not None:
            sr = await db.execute(select(Series).where(Series.id == sid))
            s = sr.scalar_one_or_none()
            if s is not None:
                title = s.title
        out.append(
            RevenueByContentRow(
                series_id=sid,
                episode_id=eid,
                title=title,
                gross_birr=float(gross or 0),
                creator_share_birr=float(creator_share or 0),
                platform_share_birr=float(platform_share or 0),
            )
        )
    return out


@router.get("/by-method", response_model=List[RevenueByMethodRow])
async def revenue_by_method(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
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
    _: User = Depends(get_current_admin),
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
    _: User = Depends(get_current_admin),
):
    result = await check_expired_passes(db)
    await db.commit()
    return ProcessExpiredResult(**result)
