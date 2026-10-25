from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List, Optional


from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import desc

from app.database import get_db
from app.deps import get_current_admin, get_current_super_admin
from app.models.ad_unlock import AdUnlockLog
from app.models.admin import ManualCashDeposit
from app.models.content import Episode, Series
from app.models.engagement import Comment, Like, ViewLog
from app.models.rating import Rating
from app.models.review import Review
from app.models.user import User
from app.models.wallet import WalletTransaction
from app.models.subscription import Subscription, TimePassPurchase
from app.schemas.admin import (
    AnalyticsContent,
    AnalyticsOverview,
    AnalyticsRetention,
    AnalyticsRevenue,
    ContentRow,
    EpisodeContentRow,
    RetentionRow,
    RevenueRow,
)

router = APIRouter(prefix="/admin/analytics", tags=["admin-analytics"])


async def _categorize_views(
    db: AsyncSession,
    views: list[ViewLog],
    episodes_map: dict[int, Episode],
    series_free_counts: dict[int, int],
) -> tuple[int, int, int, int, int]:
    coin_views = 0
    pass_views = 0
    sub_views = 0
    ad_views = 0
    free_views = 0

    user_ep_pairs = {(v.user_id, v.episode_id) for v in views if v.user_id is not None}
    ad_unlocked_set = set()
    if user_ep_pairs:
        ad_res = await db.execute(
            select(AdUnlockLog.user_id, AdUnlockLog.episode_id).where(
                AdUnlockLog.episode_id.in_([ep_id for _, ep_id in user_ep_pairs])
            )
        )
        for uid, eid in ad_res.all():
            ad_unlocked_set.add((uid, eid))

    for v in views:
        if v.subscription_id is not None:
            sub_views += 1
        elif v.pass_purchase_id is not None:
            pass_views += 1
        else:
            ep = episodes_map.get(v.episode_id)
            free_limit = series_free_counts.get(v.series_id or (ep.series_id if ep else 0), 0)
            if ep and ep.episode_number <= free_limit:
                free_views += 1
            elif (v.user_id, v.episode_id) in ad_unlocked_set:
                ad_views += 1
            else:
                coin_views += 1

    return coin_views, pass_views, sub_views, ad_views, free_views


@router.get("/overview", response_model=AnalyticsOverview)
async def overview(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_super_admin)):
    total_users = int((await db.execute(select(func.count(User.id)).where(User.role == "user"))).scalar_one())
    total_series = int((await db.execute(select(func.count(Series.id)))).scalar_one())
    total_episodes = int((await db.execute(select(func.count(Episode.id)).where(Episode.is_short.is_(False)))).scalar_one())
    total_shorts = int((await db.execute(select(func.count(Episode.id)).where(Episode.is_short.is_(True)))).scalar_one())

    now = datetime.now(timezone.utc)
    yesterday = now - timedelta(days=1)
    total_views_24h = int(
        (await db.execute(select(func.count(ViewLog.id)).where(ViewLog.created_at >= yesterday, ViewLog.watch_time_seconds >= 60))).scalar_one()
    )
    total_likes = int((await db.execute(select(func.count(Like.id)))).scalar_one())
    total_comments = int((await db.execute(select(func.count(Comment.id)))).scalar_one())
    total_ratings = int((await db.execute(select(func.count(Rating.id)))).scalar_one())
    total_reviews = int((await db.execute(select(func.count(Review.id)))).scalar_one())

    deposits = (
        await db.execute(
            select(func.coalesce(func.sum(ManualCashDeposit.amount_birr), 0))
        )
    ).scalar_one()
    deposit_tx = (
        await db.execute(
            select(func.coalesce(func.sum(WalletTransaction.amount_birr), 0)).where(WalletTransaction.type == "deposit")
        )
    ).scalar_one()
    total_birr_deposited = float(deposits or 0) + float(deposit_tx or 0)

    coins_spent = (
        await db.execute(
            select(func.coalesce(func.sum(func.abs_(WalletTransaction.amount_coins)), 0)).where(
                WalletTransaction.amount_coins < 0
            )
        )
    ).scalar_one()
    total_coins_spent = int(coins_spent or 0)

    active_subs = int(
        (await db.execute(select(func.count(Subscription.id)).where(Subscription.status == "active"))).scalar_one()
    )
    active_passes = int(
        (await db.execute(select(func.count(TimePassPurchase.id)).where(TimePassPurchase.is_active.is_(True), TimePassPurchase.expires_at > now))).scalar_one()
    )

    return AnalyticsOverview(
        total_users=total_users,
        total_series=total_series,
        total_episodes=total_episodes,
        total_shorts=total_shorts,
        total_views_24h=total_views_24h,
        total_likes=total_likes,
        total_comments=total_comments,
        total_ratings=total_ratings,
        total_reviews=total_reviews,
        total_birr_deposited=total_birr_deposited,
        total_coins_spent=total_coins_spent,
        active_subscriptions=active_subs,
        active_passes=active_passes,
    )


@router.get("/content", response_model=AnalyticsContent)
async def content_performance(
    series_id: Optional[int] = Query(default=None),
    q: Optional[str] = Query(default=None),
    limit: int = Query(default=100, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    stmt = select(Series)
    if series_id is not None:
        stmt = stmt.where(Series.id == series_id)
    if q:
        stmt = stmt.where(Series.title.ilike(f"%{q}%"))
    stmt = stmt.order_by(Series.popular_score.desc()).limit(limit)
    res = await db.execute(stmt)
    series_list = res.scalars().all()
    series_free_map = {s.id: s.free_episode_count for s in series_list}

    rows = []

    for s in series_list:
        ep_res = await db.execute(select(Episode).where(Episode.series_id == s.id))
        eps = ep_res.scalars().all()
        ep_ids = [e.id for e in eps]
        episodes_map = {e.id: e for e in eps}
        if ep_ids:
            raw_views = int(
                (await db.execute(select(func.count(ViewLog.id)).where(ViewLog.episode_id.in_(ep_ids)))).scalar_one()
            )
            q_logs_res = await db.execute(
                select(ViewLog).where(
                    ViewLog.episode_id.in_(ep_ids),
                    ViewLog.watch_time_seconds >= 60,
                )
            )
            q_logs = q_logs_res.scalars().all()
            qualified_views = len(q_logs)

            likes = int((await db.execute(select(func.count(Like.id)).where(Like.episode_id.in_(ep_ids)))).scalar_one())
            comments = int((await db.execute(select(func.count(Comment.id)).where(Comment.episode_id.in_(ep_ids)))).scalar_one())

            total_watch_seconds = sum(v.watch_time_seconds for v in q_logs)
            watch_hours = round(total_watch_seconds / 3600.0, 2) if total_watch_seconds else 0.0

            completed_count = sum(1 for v in q_logs if v.completed)
            completion_rate = round((completed_count / qualified_views) * 100.0, 1) if qualified_views else 0.0

            coin_v, pass_v, sub_v, ad_v, free_v = await _categorize_views(
                db, q_logs, episodes_map, series_free_map
            )
        else:
            raw_views = qualified_views = likes = comments = total_watch_seconds = 0
            watch_hours = completion_rate = 0.0
            coin_v = pass_v = sub_v = ad_v = free_v = 0

        rows.append(
            ContentRow(
                series_id=s.id,
                title=s.title,
                views=qualified_views,
                qualified_views=qualified_views,
                total_raw_views=raw_views,
                coin_views=coin_v,
                pass_views=pass_v,
                subscription_views=sub_v,
                ad_views=ad_v,
                free_views=free_v,
                total_watch_seconds=total_watch_seconds,
                watch_hours=watch_hours,
                likes=likes,
                comments=comments,
                popular_score=int(s.popular_score),
                completion_rate=completion_rate,
            )
        )
    return AnalyticsContent(top_content=rows)


@router.get("/content/episodes", response_model=List[EpisodeContentRow])
async def content_episodes_performance(
    series_id: Optional[int] = None,
    limit: int = Query(default=100, le=500),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    query = select(Episode, Series).join(Series, Series.id == Episode.series_id)
    if series_id is not None:
        query = query.where(Episode.series_id == series_id).order_by(Episode.episode_number)
    else:
        query = query.order_by(desc(Episode.view_count)).limit(limit)

    res = await db.execute(query)
    ep_series_pairs = res.all()

    out: List[EpisodeContentRow] = []
    for ep, s in ep_series_pairs:
        raw_views = int(
            (await db.execute(select(func.count(ViewLog.id)).where(ViewLog.episode_id == ep.id))).scalar_one()
        )
        q_logs_res = await db.execute(
            select(ViewLog).where(
                ViewLog.episode_id == ep.id,
                ViewLog.watch_time_seconds >= 60,
            )
        )
        q_logs = q_logs_res.scalars().all()
        qualified_views = len(q_logs)
        likes = int((await db.execute(select(func.count(Like.id)).where(Like.episode_id == ep.id))).scalar_one())
        comments = int((await db.execute(select(func.count(Comment.id)).where(Comment.episode_id == ep.id))).scalar_one())

        total_watch_seconds = sum(v.watch_time_seconds for v in q_logs)
        watch_hours = round(total_watch_seconds / 3600.0, 2) if total_watch_seconds else 0.0
        completed_count = sum(1 for v in q_logs if v.completed)
        completion_rate = round((completed_count / qualified_views) * 100.0, 1) if qualified_views else 0.0

        coin_v, pass_v, sub_v, ad_v, free_v = await _categorize_views(
            db, q_logs, {ep.id: ep}, {s.id: s.free_episode_count}
        )

        out.append(
            EpisodeContentRow(
                episode_id=ep.id,
                series_id=s.id,
                series_title=s.title,
                episode_number=ep.episode_number,
                title=ep.title,
                views=qualified_views,
                qualified_views=qualified_views,
                total_raw_views=raw_views,
                coin_views=coin_v,
                pass_views=pass_v,
                subscription_views=sub_v,
                ad_views=ad_v,
                free_views=free_v,
                total_watch_seconds=total_watch_seconds,
                watch_hours=watch_hours,
                likes=likes,
                comments=comments,
                completion_rate=completion_rate,
            )
        )
    return out


@router.get("/revenue", response_model=AnalyticsRevenue)
async def revenue(
    days: int = Query(default=30, le=365),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=days)
    res = await db.execute(
        select(
            func.to_char(WalletTransaction.created_at, "YYYY-MM-DD").label("bucket"),
            func.coalesce(func.sum(WalletTransaction.amount_birr), 0).label("birr"),
            func.coalesce(func.sum(func.abs_(WalletTransaction.amount_coins)), 0).label("coins"),
        )
        .where(WalletTransaction.created_at >= since)
        .group_by("bucket")
        .order_by("bucket")
    )
    rows = [RevenueRow(bucket=b, birr=float(birr or 0), coins=int(coins or 0)) for b, birr, coins in res.all()]
    return AnalyticsRevenue(rows=rows)


@router.get("/retention", response_model=AnalyticsRetention)
async def retention(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=60)
    res = await db.execute(
        select(
            func.to_char(func.date_trunc("day", User.created_at), "YYYY-MM-DD").label("cohort"),
            func.count(User.id).label("users"),
        )
        .where(User.created_at >= since)
        .group_by("cohort")
        .order_by("cohort")
    )
    out: list[RetentionRow] = []
    for cohort, _count in res.all():
        try:
            cohort_dt = datetime.strptime(cohort, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            continue
        d1 = cohort_dt + timedelta(days=1)
        d7 = cohort_dt + timedelta(days=7)
        d30 = cohort_dt + timedelta(days=30)

        async def _retention(target: datetime) -> float:
            res2 = await db.execute(
                select(func.count(func.distinct(ViewLog.user_id)))
                .join(User, User.id == ViewLog.user_id)
                .where(
                    User.created_at >= cohort_dt,
                    User.created_at < cohort_dt + timedelta(days=1),
                    ViewLog.created_at >= target,
                    ViewLog.watch_time_seconds >= 60,
                )
            )
            return float(res2.scalar_one())

        out.append(RetentionRow(cohort=cohort, d1=await _retention(d1), d7=await _retention(d7), d30=await _retention(d30)))
    return AnalyticsRetention(rows=out)
