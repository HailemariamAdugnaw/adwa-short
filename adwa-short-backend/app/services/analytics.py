from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Episode, Series
from app.models.engagement import Comment, Like, SearchQuery, ViewLog


async def recompute_popular_scores(db: AsyncSession, limit: int = 200) -> int:
    like_counts = await db.execute(
        select(Like.episode_id, func.count(Like.id))
        .join(Episode, Episode.id == Like.episode_id)
        .group_by(Like.episode_id)
    )
    likes_map: dict[int, int] = {ep_id: cnt for ep_id, cnt in like_counts.all()}

    comment_counts = await db.execute(
        select(Comment.episode_id, func.count(Comment.id))
        .where(Comment.is_hidden.is_(False))
        .group_by(Comment.episode_id)
    )
    comments_map: dict[int, int] = {ep_id: cnt for ep_id, cnt in comment_counts.all()}

    watch_sums = await db.execute(
        select(ViewLog.episode_id, func.coalesce(func.sum(ViewLog.watch_time_seconds), 0))
        .where(ViewLog.watch_time_seconds >= 60)
        .group_by(ViewLog.episode_id)
    )
    watch_map: dict[int, int] = {ep_id: int(s) for ep_id, s in watch_sums.all()}

    view_counts = await db.execute(
        select(ViewLog.episode_id, func.count(ViewLog.id))
        .where(ViewLog.watch_time_seconds >= 60)
        .group_by(ViewLog.episode_id)
    )
    views_map: dict[int, int] = {ep_id: int(c) for ep_id, c in view_counts.all()}

    series_res = await db.execute(select(Series).limit(limit))
    series_list = series_res.scalars().all()

    updated = 0
    for s in series_list:
        ep_res = await db.execute(select(Episode.id).where(Episode.series_id == s.id))
        ep_ids = [r[0] for r in ep_res.all()]
        if not ep_ids:
            s.popular_score = 0
            s.view_count = 0
            continue
        total_watch = sum(watch_map.get(eid, 0) for eid in ep_ids)
        total_likes = sum(likes_map.get(eid, 0) for eid in ep_ids)
        total_comments = sum(comments_map.get(eid, 0) for eid in ep_ids)
        total_views = sum(views_map.get(eid, 0) for eid in ep_ids)
        s.popular_score = int(total_watch + 2 * total_likes + 3 * total_comments)
        s.view_count = int(total_views)
        updated += 1
    await db.flush()
    return updated


async def trending_velocity(db: AsyncSession, top_n: int = 10) -> list[Series]:
    now = datetime.now(timezone.utc)
    yesterday = now - timedelta(days=1)
    two_days_ago = now - timedelta(days=2)

    cur = await db.execute(
        select(ViewLog.series_id, func.count(ViewLog.id))
        .where(ViewLog.created_at >= yesterday)
        .group_by(ViewLog.series_id)
    )
    cur_map: dict[int, int] = {sid: int(c) for sid, c in cur.all()}

    prior = await db.execute(
        select(ViewLog.series_id, func.count(ViewLog.id))
        .where(ViewLog.created_at >= two_days_ago, ViewLog.created_at < yesterday)
        .group_by(ViewLog.series_id)
    )
    prior_map: dict[int, int] = {sid: int(c) for sid, c in prior.all()}

    velocity: list[tuple[int, int]] = []
    for sid, c in cur_map.items():
        p = prior_map.get(sid, 0)
        if p == 0:
            velocity.append((sid, c * 2))
        else:
            velocity.append((sid, c - p))
    velocity.sort(key=lambda x: x[1], reverse=True)
    top_ids = [sid for sid, _ in velocity[:top_n]]
    if not top_ids:
        return []
    res = await db.execute(select(Series).where(Series.id.in_(top_ids), Series.is_published.is_(True)))
    return list(res.scalars().all())


async def most_searched(db: AsyncSession, top_n: int = 10) -> list[tuple[str, int]]:
    res = await db.execute(
        select(SearchQuery.query, func.count(SearchQuery.id))
        .group_by(SearchQuery.query)
        .order_by(func.count(SearchQuery.id).desc())
        .limit(top_n)
    )
    return [(q, int(c)) for q, c in res.all()]
