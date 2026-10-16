from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import Text, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_optional_user
from app.models.content import Episode, Series
from app.models.engagement import SearchQuery
from app.models.user import User
from app.schemas.content import SeriesOut

router = APIRouter(prefix="/search", tags=["search"])


@router.get("", response_model=List[SeriesOut])
async def search(
    q: str = Query(min_length=1),
    limit: int = Query(default=20, le=100),
    db: AsyncSession = Depends(get_db),
    user: Optional[User] = Depends(get_optional_user),
):
    pattern = f"%{q}%"
    res = await db.execute(
        select(Series)
        .where(
            Series.is_published.is_(True),
            or_(
                Series.title.ilike(pattern),
                Series.description.ilike(pattern),
                Series.director.ilike(pattern),
                Series.tags.cast(Text).ilike(pattern),
                Series.cast.cast(Text).ilike(pattern),
            ),
        )
        .limit(limit)
    )
    results = list(res.scalars().all())
    db.add(SearchQuery(user_id=user.id if user else None, query=q, entity_type="series"))
    await db.commit()
    return results


@router.get("/popular")
async def popular_searches(limit: int = Query(default=10, le=50), db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(SearchQuery.query, func.count(SearchQuery.id).label("c"))
        .group_by(SearchQuery.query)
        .order_by(func.count(SearchQuery.id).desc())
        .limit(limit)
    )
    return [{"query": q, "count": int(c)} for q, c in res.all()]


@router.get("/most-searched")
async def most_searched(limit: int = Query(default=10, le=50), db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(SearchQuery.query, func.count(SearchQuery.id).label("c"))
        .group_by(SearchQuery.query)
        .order_by(func.count(SearchQuery.id).desc())
        .limit(limit)
    )
    rows = res.all()
    series_out: list[dict] = []
    for q, _ in rows:
        sres = await db.execute(
            select(Series).where(Series.is_published.is_(True), Series.title.ilike(f"%{q}%")).limit(1)
        )
        s = sres.scalar_one_or_none()
        if s:
            series_out.append({"query": q, "series_id": s.id, "title": s.title, "poster_url": s.poster_url})
        if len(series_out) >= limit:
            break
    return series_out
