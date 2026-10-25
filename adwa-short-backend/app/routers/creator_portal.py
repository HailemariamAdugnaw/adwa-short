from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_creator
from app.models.ad_unlock import AdUnlockLog
from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.rating import Rating
from app.models.revenue import Creator, Payout, RevenueSplitRule, RevenueTransaction
from app.models.review import Review
from app.models.user import User
from app.schemas.creator_portal import (
    CreatorContentBreakdownItem,
    CreatorDashboardOut,
    CreatorPayoutAccountIn,
    CreatorPayoutAccountOut,
    CreatorProfileOut,
    CreatorProfileUpdateIn,
    CreatorReviewItem,
    CreatorReviewsResponse,
    CreatorSummaryOut,
    CreatorTransactionItem,
    EarningsSummaryOut,
    PerformanceMetricsOut,
)
from app.schemas.revenue import PayoutOut, SplitRuleOut
from app.services.revenue import RevenueService

router = APIRouter(prefix="/creator", tags=["creator-portal"])


@router.get("/dashboard", response_model=CreatorDashboardOut)
async def get_creator_dashboard(
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
    svc = RevenueService(db)

    # 1. Earnings Summary
    gross_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.gross_amount_birr), 0)).where(
            RevenueTransaction.creator_id == creator.id
        )
    )
    gross_revenue = float(gross_res.scalar_one() or 0)

    net_res = await db.execute(
        select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0)).where(
            RevenueTransaction.creator_id == creator.id
        )
    )
    creator_net = float(net_res.scalar_one() or 0)
    platform_commission = max(gross_revenue - creator_net, 0.0)

    paid_res = await db.execute(
        select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
            Payout.creator_id == creator.id,
            Payout.status == "processed",
        )
    )
    paid_out = float(paid_res.scalar_one() or 0)
    pending_balance = await svc.get_creator_pending_balance(creator.id)

    # 2. Performance Metrics
    series_res = await db.execute(select(Series.id).where(Series.creator_id == creator.id))
    series_ids = [r[0] for r in series_res.all()]

    ep_res = await db.execute(
        select(Episode.id).where(
            or_(
                Episode.creator_id == creator.id,
                Episode.series_id.in_(series_ids) if series_ids else False,
            )
        )
    )
    ep_ids = [r[0] for r in ep_res.all()]

    qualified_views = 0
    watch_time_seconds = 0
    if ep_ids:
        # Strict 1-minute (60 seconds) threshold
        v_res = await db.execute(
            select(
                func.count(ViewLog.id),
                func.coalesce(func.sum(ViewLog.watch_time_seconds), 0),
            ).where(
                ViewLog.episode_id.in_(ep_ids),
                ViewLog.watch_time_seconds >= 60,
            )
        )
        row = v_res.first()
        if row:
            qualified_views = int(row[0] or 0)
            watch_time_seconds = int(row[1] or 0)

    watch_time_hours = round(watch_time_seconds / 3600.0, 1)

    # 3. Recent Payouts
    payouts_res = await db.execute(
        select(Payout)
        .where(Payout.creator_id == creator.id)
        .order_by(desc(Payout.created_at))
        .limit(10)
    )
    recent_payouts = [
        PayoutOut.model_validate(p)
        for p in payouts_res.scalars().all()
    ]

    # 4. Monthly Trend
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

    monthly_trend = list(month_buckets.values())

    return CreatorDashboardOut(
        creator=CreatorSummaryOut(
            id=creator.id,
            name=creator.name,
            display_name=creator.display_name or creator.name,
            avatar_url=creator.avatar_url,
            default_revenue_split_pct=float(creator.default_revenue_split_pct or 50.0),
        ),
        earnings=EarningsSummaryOut(
            gross_revenue_birr=round(gross_revenue, 2),
            platform_commission_birr=round(platform_commission, 2),
            creator_net_birr=round(creator_net, 2),
            pending_balance_birr=round(pending_balance, 2),
            paid_out_birr=round(paid_out, 2),
        ),
        metrics=PerformanceMetricsOut(
            qualified_views=qualified_views,
            watch_time_seconds=watch_time_seconds,
            watch_time_hours=watch_time_hours,
            series_count=len(series_ids),
            episodes_count=len(ep_ids),
        ),
        pending_balance_birr=round(pending_balance, 2),
        recent_payouts=recent_payouts,
        monthly_trend=monthly_trend,
    )


@router.get("/content", response_model=List[CreatorContentBreakdownItem])
async def get_creator_content(
    filter_type: str = Query("all", pattern="^(all|series|episodes)$"),
    q: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
    series_query = select(Series).where(Series.creator_id == creator.id)
    if q:
        series_query = series_query.where(Series.title.ilike(f"%{q.strip()}%"))
    series_res = await db.execute(series_query.order_by(desc(Series.created_at)))
    series_list = series_res.scalars().all()
    series_map = {s.id: s for s in series_list}

    all_series_ids = list(series_map.keys())

    ep_query = (
        select(Episode, Series)
        .join(Series, Series.id == Episode.series_id)
        .where(
            or_(
                Episode.creator_id == creator.id,
                Episode.series_id.in_(all_series_ids) if all_series_ids else False,
            )
        )
    )
    if q:
        ep_query = ep_query.where(
            or_(
                Episode.title.ilike(f"%{q.strip()}%"),
                Series.title.ilike(f"%{q.strip()}%"),
            )
        )
    episodes_res = await db.execute(ep_query.order_by(Series.title, Episode.episode_number))
    episodes_rows = episodes_res.all()
    all_ep_ids = [ep.id for ep, _ in episodes_rows]

    # Map views breakdown with >= 60 seconds watch time qualification
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

    # Map revenue breakdown strictly from creator's credited revenue transactions
    rev_map = {eid: {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0} for eid in all_ep_ids}
    series_rev_map = {s.id: {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0} for s in series_list}

    tx_res = await db.execute(
        select(RevenueTransaction).where(RevenueTransaction.creator_id == creator.id)
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

    # Fetch ratings
    ep_rating_map: dict[int, tuple[float, int]] = {}
    if all_ep_ids:
        r_res = await db.execute(
            select(
                Rating.episode_id,
                func.coalesce(func.avg(Rating.rating), 0),
                func.count(Rating.id),
            )
            .where(Rating.episode_id.in_(all_ep_ids))
            .group_by(Rating.episode_id)
        )
        for eid, avg_r, cnt in r_res.all():
            ep_rating_map[eid] = (round(float(avg_r), 1), int(cnt))

    series_rating_map: dict[int, tuple[float, int]] = {}
    if all_series_ids:
        sr_res = await db.execute(
            select(
                Rating.series_id,
                func.coalesce(func.avg(Rating.rating), 0),
                func.count(Rating.id),
            )
            .where(Rating.series_id.in_(all_series_ids))
            .group_by(Rating.series_id)
        )
        for sid, avg_r, cnt in sr_res.all():
            series_rating_map[sid] = (round(float(avg_r), 1), int(cnt))

    items: List[CreatorContentBreakdownItem] = []

    # Series items
    if filter_type in ("all", "series"):
        for s in series_list:
            s_eps = [ep for ep, s_ep in episodes_rows if s_ep.id == s.id]
            s_views = {"coin": 0, "pass": 0, "sub": 0, "ad": 0, "total": 0}
            for ep in s_eps:
                ep_v = views_map.get(ep.id, {})
                for k in s_views:
                    s_views[k] += ep_v.get(k, 0)
            s_rev = series_rev_map.get(s.id, {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0})
            s_rating, s_cnt = series_rating_map.get(s.id, (0.0, 0))

            items.append(
                CreatorContentBreakdownItem(
                    id=s.id,
                    series_id=s.id,
                    episode_id=None,
                    title=s.title,
                    series_title=s.title,
                    episode_number=None,
                    is_series=True,
                    episodes_count=len(s_eps),
                    coin_views=s_views["coin"],
                    pass_views=s_views["pass"],
                    subscription_views=s_views["sub"],
                    ad_views=s_views["ad"],
                    total_views=s_views["total"],
                    revenue_coins_birr=round(s_rev["coins"], 2),
                    revenue_pass_birr=round(s_rev["pass"], 2),
                    revenue_sub_birr=round(s_rev["sub"], 2),
                    revenue_ad_birr=0.0,  # 100% ad revenue belongs to platform
                    total_revenue_birr=round(s_rev["total"], 2),
                    average_rating=s_rating,
                    rating_count=s_cnt,
                )
            )

    # Episode items
    if filter_type in ("all", "episodes"):
        for ep, s in episodes_rows:
            ep_v = views_map.get(ep.id, {"coin": 0, "pass": 0, "sub": 0, "ad": 0, "total": 0})
            ep_rev = rev_map.get(ep.id, {"coins": 0.0, "pass": 0.0, "sub": 0.0, "total": 0.0})
            e_rating, e_cnt = ep_rating_map.get(ep.id, (0.0, 0))

            items.append(
                CreatorContentBreakdownItem(
                    id=ep.id,
                    series_id=s.id,
                    episode_id=ep.id,
                    title=ep.title,
                    series_title=s.title,
                    episode_number=ep.episode_number,
                    is_series=False,
                    episodes_count=1,
                    coin_views=ep_v["coin"],
                    pass_views=ep_v["pass"],
                    subscription_views=ep_v["sub"],
                    ad_views=ep_v["ad"],
                    total_views=ep_v["total"],
                    revenue_coins_birr=round(ep_rev["coins"], 2),
                    revenue_pass_birr=round(ep_rev["pass"], 2),
                    revenue_sub_birr=round(ep_rev["sub"], 2),
                    revenue_ad_birr=0.0,  # 100% ad revenue belongs to platform
                    total_revenue_birr=round(ep_rev["total"], 2),
                    average_rating=e_rating,
                    rating_count=e_cnt,
                )
            )

    return items


@router.get("/reviews", response_model=CreatorReviewsResponse)
async def get_creator_reviews(
    series_id: Optional[int] = None,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, le=100),
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
    # Find all series / episodes belonging to creator
    series_res = await db.execute(select(Series.id).where(Series.creator_id == creator.id))
    c_series_ids = [r[0] for r in series_res.all()]

    ep_res = await db.execute(
        select(Episode.id).where(
            or_(
                Episode.creator_id == creator.id,
                Episode.series_id.in_(c_series_ids) if c_series_ids else False,
            )
        )
    )
    c_ep_ids = [r[0] for r in ep_res.all()]

    if not c_ep_ids:
        return CreatorReviewsResponse(average_rating=0.0, total_ratings=0, total_reviews=0, items=[])

    # Calculate overall rating stats for creator's content
    rating_stats_stmt = select(
        func.coalesce(func.avg(Rating.rating), 0),
        func.count(Rating.id),
    ).where(Rating.episode_id.in_(c_ep_ids))
    if series_id:
        rating_stats_stmt = rating_stats_stmt.where(Rating.series_id == series_id)
    r_stats_res = await db.execute(rating_stats_stmt)
    avg_r, total_ratings = r_stats_res.first() or (0.0, 0)

    # Reviews count and query
    rev_count_stmt = select(func.count(Review.id)).where(Review.episode_id.in_(c_ep_ids))
    if series_id:
        rev_count_stmt = rev_count_stmt.where(Review.series_id == series_id)
    rev_count_res = await db.execute(rev_count_stmt)
    total_reviews = int(rev_count_res.scalar_one() or 0)

    # Fetch reviews joined with user and episode
    rev_stmt = (
        select(Review, User, Episode, Series)
        .join(User, User.id == Review.user_id)
        .join(Episode, Episode.id == Review.episode_id)
        .join(Series, Series.id == Episode.series_id)
        .where(Review.episode_id.in_(c_ep_ids))
    )
    if series_id:
        rev_stmt = rev_stmt.where(Episode.series_id == series_id)

    rev_stmt = rev_stmt.order_by(desc(Review.created_at)).limit(limit).offset((page - 1) * limit)
    res = await db.execute(rev_stmt)
    rows = res.all()

    items: List[CreatorReviewItem] = []
    for rev, u, ep, ser in rows:
        # Check user's rating for this episode
        rate_res = await db.execute(
            select(Rating.rating).where(
                Rating.user_id == u.id,
                Rating.episode_id == ep.id,
            )
        )
        user_rating = rate_res.scalar_one_or_none()

        items.append(
            CreatorReviewItem(
                id=rev.id,
                user_display_name=u.display_name or "Viewer",
                series_title=ser.title,
                episode_title=ep.title,
                episode_number=ep.episode_number,
                text=rev.text,
                rating=user_rating,
                created_at=rev.created_at,
            )
        )

    return CreatorReviewsResponse(
        average_rating=round(float(avg_r), 1),
        total_ratings=int(total_ratings),
        total_reviews=total_reviews,
        items=items,
    )


@router.get("/payout-account", response_model=CreatorPayoutAccountOut)
async def get_creator_payout_account(
    creator: Creator = Depends(get_current_creator),
):
    return CreatorPayoutAccountOut(
        bank_name=creator.bank_name,
        bank_account_name=creator.bank_account_name,
        bank_account_number=creator.bank_account_number,
        payment_method=creator.payment_method,
        mobile_money_number=creator.mobile_money_number,
        tax_id=creator.tax_id,
    )


@router.put("/payout-account", response_model=CreatorPayoutAccountOut)
async def update_creator_payout_account(
    payload: CreatorPayoutAccountIn,
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
    data = payload.model_dump(exclude_unset=True)
    for field, val in data.items():
        setattr(creator, field, val)
    await db.commit()
    await db.refresh(creator)
    return CreatorPayoutAccountOut(
        bank_name=creator.bank_name,
        bank_account_name=creator.bank_account_name,
        bank_account_number=creator.bank_account_number,
        payment_method=creator.payment_method,
        mobile_money_number=creator.mobile_money_number,
        tax_id=creator.tax_id,
    )


@router.get("/transactions", response_model=List[CreatorTransactionItem])
async def get_creator_transactions(
    source_type: Optional[str] = None,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
    stmt = (
        select(RevenueTransaction, Series.title, Episode.title)
        .outerjoin(Series, Series.id == RevenueTransaction.series_id)
        .outerjoin(Episode, Episode.id == RevenueTransaction.episode_id)
        .where(RevenueTransaction.creator_id == creator.id)
    )
    if source_type:
        stmt = stmt.where(RevenueTransaction.source_type == source_type)

    stmt = stmt.order_by(desc(RevenueTransaction.created_at)).limit(limit).offset((page - 1) * limit)
    res = await db.execute(stmt)

    items: List[CreatorTransactionItem] = []
    for tx, series_title, ep_title in res.all():
        items.append(
            CreatorTransactionItem(
                id=tx.id,
                source_type=tx.source_type,
                gross_amount_birr=float(tx.gross_amount_birr or 0),
                creator_share_birr=float(tx.creator_share_birr or 0),
                platform_share_birr=float(tx.platform_share_birr or 0),
                reference=tx.reference,
                series_title=series_title,
                episode_title=ep_title,
                created_at=tx.created_at,
            )
        )
    return items


@router.get("/profile", response_model=CreatorProfileOut)
async def get_creator_profile(
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
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

    return CreatorProfileOut(
        id=creator.id,
        name=creator.name,
        display_name=creator.display_name or creator.name,
        bio=creator.bio,
        avatar_url=creator.avatar_url,
        email=creator.email,
        phone=creator.phone,
        created_at=creator.created_at,
        default_revenue_split_pct=float(creator.default_revenue_split_pct or 50.0),
        legal_contract_url=creator.legal_contract_url,
        contract_signed_date=creator.contract_signed_date,
        split_rules=rules,
    )


@router.put("/profile", response_model=CreatorProfileOut)
async def update_creator_profile(
    payload: CreatorProfileUpdateIn,
    db: AsyncSession = Depends(get_db),
    creator: Creator = Depends(get_current_creator),
):
    data = payload.model_dump(exclude_unset=True)
    for field, val in data.items():
        setattr(creator, field, val)

    # If linked to a User, also sync display_name and avatar_url
    if creator.user_id:
        u_res = await db.execute(select(User).where(User.id == creator.user_id))
        user = u_res.scalar_one_or_none()
        if user:
            if payload.display_name:
                user.display_name = payload.display_name
            if payload.avatar_url:
                user.avatar_url = payload.avatar_url

    await db.commit()
    await db.refresh(creator)

    # Return profile with split rules
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

    return CreatorProfileOut(
        id=creator.id,
        name=creator.name,
        display_name=creator.display_name or creator.name,
        bio=creator.bio,
        avatar_url=creator.avatar_url,
        email=creator.email,
        phone=creator.phone,
        created_at=creator.created_at,
        default_revenue_split_pct=float(creator.default_revenue_split_pct or 50.0),
        legal_contract_url=creator.legal_contract_url,
        contract_signed_date=creator.contract_signed_date,
        split_rules=rules,
    )
