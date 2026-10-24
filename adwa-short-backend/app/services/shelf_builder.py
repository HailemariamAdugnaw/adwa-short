from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import Text, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Series
from app.models.engagement import SearchQuery, ViewLog


def _series_to_brief(s: Series) -> dict:
    return {
        "id": s.id,
        "title": s.title,
        "poster_url": s.poster_url,
        "banner_url": s.banner_url,
        "type": s.type,
        "is_vip": s.is_vip,
        "is_exclusive": s.is_exclusive,
        "episode_count": s.total_episodes,
        "free_episode_count": s.free_episode_count,
        "popular_score": s.popular_score,
        "view_count": s.view_count,
        "category_id": s.category_id,
    }


async def _fetch_series_by_ids(db: AsyncSession, ids: list[int]) -> list[Series]:
    if not ids:
        return []
    res = await db.execute(select(Series).where(Series.id.in_(ids)))
    by_id = {s.id: s for s in res.scalars().all()}
    return [by_id[i] for i in ids if i in by_id]


async def _published_series(db: AsyncSession) -> list[Series]:
    res = await db.execute(
        select(Series).where(Series.is_published.is_(True)).order_by(desc(Series.updated_at))
    )
    return list(res.scalars().all())


async def _hot_and_new(db: AsyncSession) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True))
        .order_by(desc(Series.is_hot), desc(Series.is_new_release), desc(Series.created_at))
        .limit(20)
    )
    return list(res.scalars().all())


async def _hot(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True), Series.is_hot.is_(True))
        .order_by(desc(Series.popular_score), desc(Series.view_count), desc(Series.created_at))
        .limit(limit)
    )
    items = list(res.scalars().all())
    if items:
        return items
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True))
        .order_by(desc(Series.popular_score), desc(Series.view_count))
        .limit(limit)
    )
    return list(res.scalars().all())


async def _new_releases(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True), Series.is_new_release.is_(True))
        .order_by(desc(Series.created_at))
        .limit(limit)
    )
    items = list(res.scalars().all())
    if items:
        return items
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True))
        .order_by(desc(Series.created_at))
        .limit(limit)
    )
    return list(res.scalars().all())


async def _most_seen(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True))
        .order_by(desc(Series.view_count))
        .limit(limit)
    )
    return list(res.scalars().all())


async def _frequent_seen(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(ViewLog.series_id, func.count(func.distinct(ViewLog.user_id)), func.count(ViewLog.id))
        .where(ViewLog.series_id.is_not(None))
        .group_by(ViewLog.series_id)
        .order_by(desc(func.count(ViewLog.id) / (func.count(func.distinct(ViewLog.user_id)) + 1)))
        .limit(limit)
    )
    rows = res.all()
    ids = [r[0] for r in rows if r[0] is not None]
    return await _fetch_series_by_ids(db, ids)


async def _trending(db: AsyncSession, limit: int = 20) -> list[Series]:
    now = datetime.now(timezone.utc)
    yesterday = now - timedelta(days=1)
    two_days_ago = now - timedelta(days=2)

    cur = await db.execute(
        select(ViewLog.series_id, func.count(ViewLog.id))
        .where(ViewLog.created_at >= yesterday, ViewLog.series_id.is_not(None))
        .group_by(ViewLog.series_id)
    )
    cur_map = {sid: int(c) for sid, c in cur.all()}

    prior = await db.execute(
        select(ViewLog.series_id, func.count(ViewLog.id))
        .where(ViewLog.created_at >= two_days_ago, ViewLog.created_at < yesterday, ViewLog.series_id.is_not(None))
        .group_by(ViewLog.series_id)
    )
    prior_map = {sid: int(c) for sid, c in prior.all()}

    velocity = []
    for sid, c in cur_map.items():
        p = prior_map.get(sid, 0)
        score = c * 2 if p == 0 else c - p
        velocity.append((sid, score))
    velocity.sort(key=lambda x: x[1], reverse=True)
    ids = [sid for sid, _ in velocity[:limit]]
    return await _fetch_series_by_ids(db, ids)


async def _most_searched(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(SearchQuery.query, func.count(SearchQuery.id).label("c"))
        .where(SearchQuery.entity_type == "series")
        .group_by(SearchQuery.query)
        .order_by(desc("c"))
        .limit(limit)
    )
    queries = [q for q, _ in res.all()]
    if not queries:
        return []
    matched = []
    for q in queries:
        sres = await db.execute(
            select(Series).where(Series.is_published.is_(True), Series.title.ilike(f"%{q}%")).limit(1)
        )
        s = sres.scalar_one_or_none()
        if s and s not in matched:
            matched.append(s)
        if len(matched) >= limit:
            break
    return matched


async def _popular(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True))
        .order_by(desc(Series.popular_score))
        .limit(limit)
    )
    return list(res.scalars().all())


async def _most_viral(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True), Series.viral_external_score > 0)
        .order_by(desc(Series.viral_external_score))
        .limit(limit)
    )
    items = list(res.scalars().all())
    if items:
        return items
    res = await db.execute(
        select(Series).where(Series.is_published.is_(True), Series.is_most_viral.is_(True)).limit(limit)
    )
    return list(res.scalars().all())


async def _vip(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series).where(Series.is_published.is_(True), Series.is_vip.is_(True)).limit(limit)
    )
    return list(res.scalars().all())


async def _exclusive(db: AsyncSession, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series).where(Series.is_published.is_(True), Series.is_exclusive.is_(True)).limit(limit)
    )
    return list(res.scalars().all())


async def _by_category_name(db: AsyncSession, name: str, limit: int = 20) -> list[Series]:
    from app.models.content import Category

    res = await db.execute(
        select(Series)
        .join(Category, Category.id == Series.category_id, isouter=True)
        .where(Series.is_published.is_(True), Category.name.ilike(name))
        .limit(limit)
    )
    return list(res.scalars().all())


async def _by_tag(db: AsyncSession, tag: str, limit: int = 20) -> list[Series]:
    res = await db.execute(
        select(Series)
        .where(Series.is_published.is_(True), Series.tags.cast(Text).ilike(f'%"{tag}"%'))
        .limit(limit)
    )
    return list(res.scalars().all())


async def build_home_shelves(db: AsyncSession) -> list[dict]:
    hot_new = await _hot_and_new(db)
    most_seen = await _most_seen(db)
    frequent = await _frequent_seen(db)
    trending = await _trending(db)
    most_searched_items = await _most_searched(db)
    popular = await _popular(db)
    viral = await _most_viral(db)
    vip = await _vip(db)
    exclusive = await _exclusive(db)
    hot = await _hot(db)
    new_releases = await _new_releases(db)

    genre_shelves = [
        ("romance", "Romance"),
        ("family", "Family"),
        ("drama", "Drama"),
        ("bad-character", "Bad Character"),
        ("good-character", "Good Character"),
        ("documentary", "Documentary"),
        ("ethiopia", "Ethiopia"),
        ("biography", "Biography"),
        ("celebrity", "Celebrity"),
    ]
    genre_items = {}
    for key, label in genre_shelves:
        items = await _by_category_name(db, label, limit=20)
        if not items:
            items = await _by_tag(db, label, limit=20)
        genre_items[key] = (label, items)

    shelves: list[dict] = [
        {"key": "hot_new", "title": "Hot & New Releases", "type": "banner", "items": [_series_to_brief(s) for s in hot_new[:10]]},
        {"key": "popular", "title": "Popular", "type": "grid", "items": [_series_to_brief(s) for s in popular]},
        {"key": "hot", "title": "Hot", "type": "grid", "items": [_series_to_brief(s) for s in hot]},
        {"key": "new_releases", "title": "New Releases", "type": "grid", "items": [_series_to_brief(s) for s in new_releases]},
        {"key": "trending", "title": "Top Trending", "type": "row", "items": [_series_to_brief(s) for s in trending]},
        {"key": "most_seen", "title": "Most Seen", "type": "row", "items": [_series_to_brief(s) for s in most_seen]},
        {"key": "frequent_seen", "title": "Frequent Seen", "type": "row", "items": [_series_to_brief(s) for s in frequent]},
        {"key": "most_searched", "title": "Most Searched", "type": "row", "items": [_series_to_brief(s) for s in most_searched_items]},
        {"key": "most_viral", "title": "Most Viral", "type": "row", "items": [_series_to_brief(s) for s in viral]},
        {"key": "vip", "title": "VIP", "type": "row", "items": [_series_to_brief(s) for s in vip]},
        {"key": "exclusive", "title": "Exclusive", "type": "row", "items": [_series_to_brief(s) for s in exclusive]},
    ]
    for key, (label, items) in genre_items.items():
        shelves.append({"key": f"genre_{key}", "title": label, "type": "row", "items": [_series_to_brief(s) for s in items]})
    return shelves
