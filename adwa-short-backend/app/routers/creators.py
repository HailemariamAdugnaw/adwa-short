from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_super_admin
from app.models.ad_unlock import AdUnlockLog
from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.revenue import (
    Creator,
    Payout,
    RevenueSplitRule,
    RevenueTransaction,
)
from app.models.user import User
from app.models.wallet import Wallet
from app.security import hash_password
from app.schemas.revenue import (
    CreatorContentItem,
    CreatorCreate,
    CreatorDetailOut,
    CreatorListRow,
    CreatorOption,
    CreatorOut,
    CreatorRevenueSummary,
    CreatorUpdate,
    PayoutCreate,
    PayoutOut,
    SplitRuleCreate,
    SplitRuleOut,
)
from app.services.revenue import RevenueService

router = APIRouter(prefix="/creators", tags=["creators"])


@router.post("", response_model=CreatorOut, status_code=status.HTTP_201_CREATED)
async def create_creator(
    payload: CreatorCreate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    data = payload.model_dump()
    split_pct = data.get("default_revenue_split_pct")
    if split_pct is not None and split_pct != 50.0 and not admin.is_super_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Super Admins can configure custom revenue split percentages",
        )
    password = data.pop("password", None)
    creator = Creator(**data)
    db.add(creator)
    await db.flush()

    # Link or auto-create User account for creator authentication
    user = None
    if creator.email or creator.phone:
        conds = []
        if creator.email:
            conds.append(User.email.ilike(creator.email.strip()))
        if creator.phone:
            conds.append(User.phone == creator.phone.strip())
        res = await db.execute(select(User).where(or_(*conds)))
        candidates = res.scalars().all()
        for cand in candidates:
            c_check = await db.execute(select(Creator.id).where(Creator.user_id == cand.id))
            if c_check.scalar_one_or_none() is None:
                user = cand
                break

    if user is None:
        base_phone = creator.phone or f"+2519{creator.id:08d}"
        p_check = await db.execute(select(User.id).where(User.phone == base_phone))
        if p_check.scalar_one_or_none() is not None:
            base_phone = f"+2519{creator.id:08d}"

        base_email = creator.email
        if base_email:
            e_check = await db.execute(select(User.id).where(User.email.ilike(base_email.strip())))
            if e_check.scalar_one_or_none() is not None:
                base_email = None

        user = User(
            phone=base_phone,
            email=base_email,
            password_hash=hash_password(password or "creator123"),
            display_name=creator.display_name or creator.name,
            role="creator",
            is_active=True,
        )
        db.add(user)
        await db.flush()
        db.add(Wallet(user_id=user.id, balance_birr=0, balance_coins=0))

    if user is not None:
        if user.role != "super_admin":
            user.role = "creator"
        creator.user_id = user.id

    await db.commit()
    await db.refresh(creator)
    return creator


@router.get("", response_model=List[CreatorListRow])
async def list_creators(
    is_active: Optional[bool] = None,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    stmt = select(Creator)
    if is_active is not None:
        stmt = stmt.where(Creator.is_active.is_(is_active))
    stmt = stmt.order_by(desc(Creator.created_at)).limit(limit).offset((page - 1) * limit)
    res = await db.execute(stmt)
    creators = list(res.scalars().all())

    out: List[CreatorListRow] = []
    svc = RevenueService(db)
    for c in creators:
        content_count_res = await db.execute(
            select(func.count(Series.id)).where(Series.creator_id == c.id)
        )
        content_count = int(content_count_res.scalar_one() or 0)

        ep_ids_res = await db.execute(
            select(Episode.id).join(Series, Series.id == Episode.series_id).where(
                (Episode.creator_id == c.id) | (Series.creator_id == c.id)
            )
        )
        ep_ids = [r[0] for r in ep_ids_res.all()]
        if ep_ids:
            views_res = await db.execute(
                select(func.count(func.distinct(ViewLog.id))).where(ViewLog.episode_id.in_(ep_ids))
            )
            total_views = int(views_res.scalar_one() or 0)
        else:
            total_views = 0

        gross_res = await db.execute(
            select(func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0)).where(
                RevenueTransaction.creator_id == c.id
            )
        )
        gross = float(gross_res.scalar_one() or 0)
        share_res = await db.execute(
            select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0)).where(
                RevenueTransaction.creator_id == c.id
            )
        )
        creator_net = float(share_res.scalar_one() or 0)

        pending = await svc.get_creator_pending_balance(c.id)

        last_payout_res = await db.execute(
            select(Payout.created_at)
            .where(Payout.creator_id == c.id, Payout.status.in_(("processed", "pending")))
            .order_by(desc(Payout.created_at))
            .limit(1)
        )
        last_payout_row = last_payout_res.first()
        last_payout_date = last_payout_row[0] if last_payout_row else None

        out.append(
            CreatorListRow(
                id=c.id,
                name=c.name,
                phone=c.phone,
                email=c.email,
                display_name=c.display_name,
                avatar_url=c.avatar_url,
                legal_contract_url=c.legal_contract_url,
                contract_signed_date=c.contract_signed_date,
                bank_account_name=c.bank_account_name,
                bank_account_number=c.bank_account_number,
                bank_name=c.bank_name,
                payment_method=c.payment_method,
                default_revenue_split_pct=float(c.default_revenue_split_pct or 0),
                is_active=c.is_active,
                created_at=c.created_at,
                updated_at=c.updated_at,
                total_views=total_views,
                gross_revenue=gross,
                creator_net=creator_net,
                pending_balance=pending,
                content_count=content_count,
                last_payout_date=last_payout_date,
            )
        )
    return out


@router.get("/lookup", response_model=List[CreatorOption])
async def list_creator_options(
    is_active: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    stmt = select(Creator)
    if is_active is not None:
        stmt = stmt.where(Creator.is_active.is_(is_active))
    stmt = stmt.order_by(Creator.name.asc())
    res = await db.execute(stmt)
    creators = list(res.scalars().all())
    return [
        CreatorOption(
            id=c.id,
            name=c.name,
            display_name=c.display_name,
            default_revenue_split_pct=float(c.default_revenue_split_pct or 50.0),
            is_active=c.is_active,
        )
        for c in creators
    ]


@router.get("/{creator_id}", response_model=CreatorDetailOut)
async def get_creator(
    creator_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")

    svc = RevenueService(db)
    pending = await svc.get_creator_pending_balance(creator.id)
    gross_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0)).where(
            RevenueTransaction.creator_id == creator.id
        )
    )
    lifetime_gross = float(gross_res.scalar_one() or 0)
    share_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0)).where(
            RevenueTransaction.creator_id == creator.id
        )
    )
    lifetime_share = float(share_res.scalar_one() or 0)
    paid_res = await db.execute(
        select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
            Payout.creator_id == creator.id,
            Payout.status.in_(("processed", "pending")),
        )
    )
    lifetime_paid = float(paid_res.scalar_one() or 0)

    rules_res = await db.execute(
        select(RevenueSplitRule)
        .where(RevenueSplitRule.creator_id == creator.id, RevenueSplitRule.is_active.is_(True))
        .order_by(desc(RevenueSplitRule.created_at))
    )
    rules = [
        SplitRuleOut(
            id=r.id,
            creator_id=r.creator_id,
            series_id=r.series_id,
            episode_id=r.episode_id,
            creator_share_pct=float(r.creator_share_pct),
            is_active=r.is_active,
            created_at=r.created_at,
        )
        for r in rules_res.scalars().all()
    ]

    return CreatorDetailOut(
        id=creator.id,
        name=creator.name,
        phone=creator.phone,
        email=creator.email,
        display_name=creator.display_name,
        avatar_url=creator.avatar_url,
        legal_contract_url=creator.legal_contract_url,
        contract_signed_date=creator.contract_signed_date,
        bank_account_name=creator.bank_account_name,
        bank_account_number=creator.bank_account_number,
        bank_name=creator.bank_name,
        payment_method=creator.payment_method,
        default_revenue_split_pct=float(creator.default_revenue_split_pct or 0),
        is_active=creator.is_active,
        created_at=creator.created_at,
        updated_at=creator.updated_at,
        pending_balance_birr=pending,
        lifetime_gross_birr=lifetime_gross,
        lifetime_creator_share_birr=lifetime_share,
        lifetime_paid_out_birr=lifetime_paid,
        split_rules=rules,
    )


@router.put("/{creator_id}", response_model=CreatorOut)
async def update_creator(
    creator_id: int,
    payload: CreatorUpdate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")
    data = payload.model_dump(exclude_unset=True)
    if "default_revenue_split_pct" in data:
        new_val = float(data["default_revenue_split_pct"])
        curr_val = float(creator.default_revenue_split_pct or 50.0)
        if new_val != curr_val and not admin.is_super_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only Super Admins can adjust revenue split percentages",
            )
    for k, v in data.items():
        setattr(creator, k, v)
    await db.commit()
    await db.refresh(creator)
    return creator


@router.delete("/{creator_id}", status_code=status.HTTP_200_OK)
async def deactivate_creator(
    creator_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")
    creator.is_active = False
    await db.commit()
    return {"id": creator.id, "is_active": False}


@router.put("/{creator_id}/split", response_model=SplitRuleOut)
async def set_creator_split(
    creator_id: int,
    payload: SplitRuleCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")

    if payload.series_id is not None:
        sres = await db.execute(select(Series).where(Series.id == payload.series_id))
        if sres.scalar_one_or_none() is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    if payload.episode_id is not None:
        eres = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
        if eres.scalar_one_or_none() is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    existing_res = await db.execute(
        select(RevenueSplitRule).where(
            RevenueSplitRule.creator_id == creator.id,
            RevenueSplitRule.series_id.is_(payload.series_id) if payload.series_id is not None
            else RevenueSplitRule.series_id.is_(None),
            RevenueSplitRule.episode_id.is_(payload.episode_id) if payload.episode_id is not None
            else RevenueSplitRule.episode_id.is_(None),
        )
    )
    rule = existing_res.scalar_one_or_none()
    if rule is None:
        rule = RevenueSplitRule(
            creator_id=creator.id,
            series_id=payload.series_id,
            episode_id=payload.episode_id,
            creator_share_pct=payload.creator_share_pct,
            is_active=True,
        )
        db.add(rule)
    else:
        rule.creator_share_pct = payload.creator_share_pct
        rule.is_active = True
    await db.commit()
    await db.refresh(rule)
    return rule


@router.delete("/{creator_id}/split/{rule_id}", status_code=status.HTTP_200_OK)
async def delete_creator_split_rule(
    creator_id: int,
    rule_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(RevenueSplitRule).where(
            RevenueSplitRule.id == rule_id,
            RevenueSplitRule.creator_id == creator_id,
        )
    )
    rule = res.scalar_one_or_none()
    if rule is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Split rule not found")
    await db.delete(rule)
    await db.commit()
    return {"deleted": True, "id": rule_id}


@router.get("/{creator_id}/revenue", response_model=CreatorRevenueSummary)
async def creator_revenue_summary(
    creator_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")

    svc = RevenueService(db)
    pending = await svc.get_creator_pending_balance(creator.id)

    gross_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0)).where(
            RevenueTransaction.creator_id == creator.id
        )
    )
    gross = float(gross_res.scalar_one() or 0)
    share_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0)).where(
            RevenueTransaction.creator_id == creator.id
        )
    )
    creator_net = float(share_res.scalar_one() or 0)
    platform_share = gross - creator_net
    paid_res = await db.execute(
        select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
            Payout.creator_id == creator.id,
            Payout.status.in_(("processed", "pending")),
        )
    )
    paid = float(paid_res.scalar_one() or 0)

    ep_ids_res = await db.execute(
        select(Episode.id).join(Series, Series.id == Episode.series_id).where(
            (Episode.creator_id == creator.id) | (Series.creator_id == creator.id)
        )
    )
    ep_ids = [r[0] for r in ep_ids_res.all()]
    if ep_ids:
        views_res = await db.execute(
            select(func.count(func.distinct(ViewLog.id))).where(
                ViewLog.episode_id.in_(ep_ids),
                ViewLog.watch_time_seconds >= 60,
            )
        )
        total_views = int(views_res.scalar_one() or 0)
    else:
        total_views = 0

    month_res = await db.execute(
        select(
            RevenueTransaction.created_at,
            RevenueTransaction.gross_amount_birr,
            RevenueTransaction.creator_share_birr,
        )
        .where(RevenueTransaction.creator_id == creator.id)
        .order_by(desc(RevenueTransaction.created_at))
    )
    month_buckets: dict[str, dict[str, float]] = {}
    for created_at, gross, share in month_res.all():
        if created_at is None:
            continue
        bucket = created_at.strftime("%Y-%m")
        if bucket not in month_buckets:
            month_buckets[bucket] = {"month": bucket, "gross": 0.0, "creator_net": 0.0, "platform": 0.0}
        month_buckets[bucket]["gross"] += float(gross or 0)
        month_buckets[bucket]["creator_net"] += float(share or 0)
        month_buckets[bucket]["platform"] += float(gross or 0) - float(share or 0)
    by_month = list(month_buckets.values())

    return CreatorRevenueSummary(
        creator_id=creator.id,
        gross_amount_birr=gross,
        platform_share_birr=platform_share,
        creator_net_birr=creator_net,
        paid_out_birr=paid,
        pending_balance_birr=pending,
        total_views=total_views,
        by_month=by_month,
    )


@router.get("/{creator_id}/content", response_model=List[CreatorContentItem])
async def creator_content(
    creator_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    if res.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")

    series_res = await db.execute(
        select(Series).where(Series.creator_id == creator_id).order_by(desc(Series.created_at))
    )
    series_list = series_res.scalars().all()

    # Get all episodes belonging to this creator or belonging to this creator's series
    episodes_res = await db.execute(
        select(Episode, Series)
        .join(Series, Series.id == Episode.series_id)
        .where((Episode.creator_id == creator_id) | (Series.creator_id == creator_id))
        .order_by(Series.title, Episode.episode_number)
    )
    episodes_rows = episodes_res.all()
    all_ep_ids = [ep.id for ep, _ in episodes_rows]

    # Map views breakdown
    views_map = {eid: {"coin": 0, "pass": 0, "sub": 0, "ad": 0, "total": 0} for eid in all_ep_ids}
    if all_ep_ids:
        views_res = await db.execute(
            select(ViewLog).where(
                ViewLog.episode_id.in_(all_ep_ids),
                ViewLog.watch_time_seconds >= 60,
            )
        )
        v_logs = views_res.scalars().all()
        ad_unlocked_set = set()
        user_ep_pairs = {(v.user_id, v.episode_id) for v in v_logs if v.user_id is not None}
        if user_ep_pairs:
            ad_res = await db.execute(
                select(AdUnlockLog.user_id, AdUnlockLog.episode_id).where(
                    AdUnlockLog.episode_id.in_(all_ep_ids)
                )
            )
            for uid, eid in ad_res.all():
                ad_unlocked_set.add((uid, eid))

        for v in v_logs:
            stats = views_map.get(v.episode_id)
            if not stats:
                continue
            stats["total"] += 1
            if v.subscription_id is not None:
                stats["sub"] += 1
            elif v.pass_purchase_id is not None:
                stats["pass"] += 1
            elif (v.user_id, v.episode_id) in ad_unlocked_set:
                stats["ad"] += 1
            else:
                stats["coin"] += 1

    # Map revenue breakdown from RevenueTransaction
    rev_map = {eid: {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0} for eid in all_ep_ids}
    series_rev_map = {s.id: {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0} for s in series_list}

    tx_res = await db.execute(
        select(RevenueTransaction).where(RevenueTransaction.creator_id == creator_id)
    )
    for tx in tx_res.scalars().all():
        c_share = float(tx.creator_share_birr or 0.0)
        if tx.episode_id and tx.episode_id in rev_map:
            rev_stats = rev_map[tx.episode_id]
            if tx.source_type == "coin_payment":
                rev_stats["coins"] += c_share
            elif tx.source_type == "pass_consumption":
                rev_stats["pass"] += c_share
            elif tx.source_type == "subscription_consumption":
                rev_stats["sub"] += c_share
            rev_stats["total"] += c_share

        if tx.series_id and tx.series_id in series_rev_map:
            s_stats = series_rev_map[tx.series_id]
            if tx.source_type == "coin_payment":
                s_stats["coins"] += c_share
            elif tx.source_type == "pass_consumption":
                s_stats["pass"] += c_share
            elif tx.source_type == "subscription_consumption":
                s_stats["sub"] += c_share
            s_stats["total"] += c_share

    out: List[CreatorContentItem] = []
    # 1. Series rows (is_series=True)
    for s in series_list:
        s_eps = [ep for ep, s_ep in episodes_rows if s_ep.id == s.id]
        s_views = {"coin": 0, "pass": 0, "sub": 0, "ad": 0, "total": 0}
        for ep in s_eps:
            ep_v = views_map.get(ep.id, {})
            for k in s_views:
                s_views[k] += ep_v.get(k, 0)
        s_rev = series_rev_map.get(s.id, {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0})
        out.append(
            CreatorContentItem(
                series_id=s.id,
                episode_id=None,
                title=s.title,
                series_title=s.title,
                episode_number=None,
                is_series=True,
                episodes_count=len(s_eps),
                total_views=s_views["total"],
                coin_views=s_views["coin"],
                pass_views=s_views["pass"],
                subscription_views=s_views["sub"],
                ad_views=s_views["ad"],
                view_count=s_views["total"],
                revenue_coins_birr=round(s_rev["coins"], 2),
                revenue_pass_birr=round(s_rev["pass"], 2),
                revenue_sub_birr=round(s_rev["sub"], 2),
                total_revenue_birr=round(s_rev["total"], 2),
            )
        )

    # 2. Episode rows (is_series=False)
    for ep, s in episodes_rows:
        ep_v = views_map.get(ep.id, {"coin": 0, "pass": 0, "sub": 0, "ad": 0, "total": 0})
        ep_rev = rev_map.get(ep.id, {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0})
        out.append(
            CreatorContentItem(
                series_id=s.id,
                episode_id=ep.id,
                title=ep.title,
                series_title=s.title,
                episode_number=ep.episode_number,
                is_series=False,
                episodes_count=1,
                total_views=ep_v["total"],
                coin_views=ep_v["coin"],
                pass_views=ep_v["pass"],
                subscription_views=ep_v["sub"],
                ad_views=ep_v["ad"],
                view_count=ep_v["total"],
                revenue_coins_birr=round(ep_rev["coins"], 2),
                revenue_pass_birr=round(ep_rev["pass"], 2),
                revenue_sub_birr=round(ep_rev["sub"], 2),
                total_revenue_birr=round(ep_rev["total"], 2),
            )
        )

    return out


@router.post("/{creator_id}/payouts", response_model=PayoutOut, status_code=status.HTTP_201_CREATED)
async def create_payout(
    creator_id: int,
    payload: PayoutCreate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(Creator).where(Creator.id == creator_id))
    creator = res.scalar_one_or_none()
    if creator is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Creator not found")

    svc = RevenueService(db)
    pending = await svc.get_creator_pending_balance(creator.id)
    if float(payload.amount_birr) > pending:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Payout exceeds pending balance ({pending})",
        )

    payout = await svc.process_payout(
        creator_id=creator.id,
        amount_birr=float(payload.amount_birr),
        admin_id=admin.id,
        notes=payload.notes,
        bank_account_number=payload.bank_account_number or creator.bank_account_number,
        bank_account_name=payload.bank_account_name or creator.bank_account_name or creator.name,
        bank_name=payload.bank_name or creator.bank_name or "Commercial Bank of Ethiopia (CBE)",
        auto_disburse=True,
    )
    await db.commit()
    await db.refresh(payout)
    return payout


@router.get("/{creator_id}/payouts", response_model=List[PayoutOut])
async def list_payouts(
    creator_id: int,
    limit: int = Query(default=50, le=200),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(Payout)
        .where(Payout.creator_id == creator_id)
        .order_by(desc(Payout.created_at))
        .limit(limit)
        .offset(offset)
    )
    return list(res.scalars().all())
