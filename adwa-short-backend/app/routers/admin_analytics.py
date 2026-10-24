from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin
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
    RetentionRow,
    RevenueRow,
)

router = APIRouter(prefix="/admin/analytics", tags=["admin-analytics"])


@router.get("/overview", response_model=AnalyticsOverview)
async def overview(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    total_users = int((await db.execute(select(func.count(User.id)).where(User.role == "user"))).scalar_one())
    total_series = int((await db.execute(select(func.count(Series.id)))).scalar_one())
    total_episodes = int((await db.execute(select(func.count(Episode.id)).where(Episode.is_short.is_(False)))).scalar_one())
    total_shorts = int((await db.execute(select(func.count(Episode.id)).where(Episode.is_short.is_(True)))).scalar_one())

    now = datetime.now(timezone.utc)
    yesterday = now - timedelta(days=1)
    total_views_24h = int(
        (await db.execute(select(func.count(ViewLog.id)).where(ViewLog.created_at >= yesterday))).scalar_one()
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
    limit: int = Query(default=20, le=100),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    rows = []
    res = await db.execute(select(Series).order_by(Series.popular_score.desc()).limit(limit))
    for s in res.scalars().all():
        ep_res = await db.execute(select(Episode.id).where(Episode.series_id == s.id))
        ep_ids = [r[0] for r in ep_res.all()]
        if ep_ids:
            views = int((await db.execute(select(func.count(ViewLog.id)).where(ViewLog.episode_id.in_(ep_ids)))).scalar_one())
            likes = int((await db.execute(select(func.count(Like.id)).where(Like.episode_id.in_(ep_ids)))).scalar_one())
            comments = int((await db.execute(select(func.count(Comment.id)).where(Comment.episode_id.in_(ep_ids)))).scalar_one())
            watch_secs_res = await db.execute(
                select(func.coalesce(func.sum(ViewLog.watch_time_seconds), 0)).where(ViewLog.episode_id.in_(ep_ids))
            )
            watch_secs = float(watch_secs_res.scalar_one() or 0)
            completed_res = await db.execute(
                select(func.count(ViewLog.id)).where(ViewLog.episode_id.in_(ep_ids), ViewLog.completed.is_(True))
            )
            completed = int(completed_res.scalar_one() or 0)
        else:
            views = likes = comments = 0
            watch_secs = 0.0
            completed = 0
        watch_hours = round(watch_secs / 3600.0, 2) if watch_secs else 0.0
        completion_rate = round((completed / views) * 100.0, 1) if views else 0.0
        rows.append(
            ContentRow(
                series_id=s.id,
                title=s.title,
                views=views,
                likes=likes,
                comments=comments,
                popular_score=int(s.popular_score),
                watch_hours=watch_hours,
                completion_rate=completion_rate,
            )
        )
    return AnalyticsContent(top_content=rows)


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
                .where(User.created_at >= cohort_dt, User.created_at < cohort_dt + timedelta(days=1), ViewLog.created_at >= target)
            )
            return float(res2.scalar_one())

        out.append(RetentionRow(cohort=cohort, d1=await _retention(d1), d7=await _retention(d7), d30=await _retention(d30)))
    return AnalyticsRetention(rows=out)
