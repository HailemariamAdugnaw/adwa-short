from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_optional_user
from app.models.content import Episode, Series
from app.models.user import User
from app.schemas.content import ShortsFeedItem
from app.services.monetization import AccessDenied, AccessResult, resolve_access

router = APIRouter(prefix="/shorts", tags=["shorts"])


_ACCESS_REASON_MAP = {
    AccessResult.FREE: ("free", True),
    AccessResult.ALLOWED_AD: ("ad_unlock", True),
    AccessResult.ALLOWED_PASS: ("pass", True),
    AccessResult.ALLOWED_SUBSCRIPTION: ("subscription", True),
    AccessResult.ALLOWED_COINS: ("coins", True),
    AccessResult.BLOCKED_NEED_AD: ("need_ad", False),
    AccessResult.BLOCKED_NEED_COINS: ("need_coins", False),
    AccessResult.BLOCKED_NEED_PASS: ("need_pass", False),
    AccessResult.BLOCKED_NEED_SUBSCRIPTION: ("need_subscription", False),
}


async def _build_item(
    db: AsyncSession,
    ep: Episode,
    series: Series,
    user: User | None,
) -> ShortsFeedItem:
    is_accessible = False
    access_reason = "need_subscription"
    try:
        result = await resolve_access(db, user, ep, series, deduct_coins=False)
        reason, ok = _ACCESS_REASON_MAP.get(result, ("need_subscription", False))
        is_accessible = ok
        access_reason = reason
    except AccessDenied as e:
        reason, ok = _ACCESS_REASON_MAP.get(e.reason, ("need_subscription", False))
        is_accessible = ok
        access_reason = reason

    return ShortsFeedItem(
        episode_id=ep.id,
        series_id=ep.series_id,
        title=ep.title,
        series_title=series.title,
        description=ep.description or series.description,
        vertical_video_url=ep.vertical_video_url or ep.video_url,
        video_url=ep.video_url,
        thumbnail_url=ep.thumbnail_url,
        duration_seconds=ep.duration_seconds,
        episode_number=ep.episode_number,
        total_episodes=series.total_episodes,
        view_count=ep.view_count,
        coin_cost=ep.coin_cost,
        is_short=ep.is_short,
        is_accessible=is_accessible,
        access_reason=access_reason,
        creator_id=ep.creator_id or series.creator_id,
    )


@router.get("/feed", response_model=list[ShortsFeedItem])
async def shorts_feed(
    limit: int = Query(default=20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_optional_user),
):
    res = await db.execute(
        select(Episode, Series)
        .join(Series, Series.id == Episode.series_id)
        .where(Episode.is_published.is_(True), Series.is_published.is_(True))
        .order_by(desc(Episode.view_count), desc(Episode.created_at))
        .limit(limit)
        .offset(offset)
    )
    out: list[ShortsFeedItem] = []
    for ep, series in res.all():
        out.append(await _build_item(db, ep, series, user))
    return out


@router.get("/feed/count")
async def shorts_feed_count(
    db: AsyncSession = Depends(get_db),
):
    res = await db.execute(
        select(func.count(Episode.id))
        .select_from(Episode)
        .join(Series, Series.id == Episode.series_id)
        .where(Episode.is_published.is_(True), Series.is_published.is_(True))
    )
    return {"count": int(res.scalar_one() or 0)}
