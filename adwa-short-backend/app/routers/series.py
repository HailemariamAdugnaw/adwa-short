from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.deps import get_current_admin, get_optional_user
from app.models.content import Episode, Series
from app.models.user import User
from app.schemas.content import SeriesCreate, SeriesDetailOut, SeriesOut, SeriesUpdate
from app.services.audit import log_activity

router = APIRouter(prefix="/series", tags=["series"])


@router.get("", response_model=list[SeriesOut])
async def list_series(
    category_id: int | None = Query(default=None),
    is_vip: bool | None = Query(default=None),
    is_short: bool | None = Query(default=None),
    status: str | None = Query(default=None, pattern="^(all|published|pending)$"),
    q: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int = Query(default=50, le=200),
    offset: int | None = Query(default=None, ge=0),
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_optional_user),
):
    is_admin = user is not None and user.role == "admin"
    stmt = select(Series)
    if is_admin:
        if status == "published":
            stmt = stmt.where(Series.is_published.is_(True))
        elif status == "pending":
            stmt = stmt.where(Series.is_published.is_(False))
    else:
        stmt = stmt.where(Series.is_published.is_(True))
    if category_id is not None:
        stmt = stmt.where(Series.category_id == category_id)
    if is_vip is not None:
        stmt = stmt.where(Series.is_vip.is_(is_vip))
    if is_short is not None:
        stmt = stmt.where(Series.type == ("short" if is_short else "series"))
    if q:
        pat = f"%{q}%"
        stmt = stmt.where(or_(Series.title.ilike(pat), Series.director.ilike(pat)))
    stmt = stmt.order_by(Series.created_at.desc())
    if page is not None and offset is None:
        stmt = stmt.limit(limit).offset((page - 1) * limit)
    elif offset is not None:
        stmt = stmt.limit(limit).offset(offset)
    else:
        stmt = stmt.limit(limit)
    res = await db.execute(stmt)
    return list(res.scalars().all())


@router.get("/{series_id}", response_model=SeriesDetailOut)
async def get_series(
    series_id: int,
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_optional_user),
):
    res = await db.execute(
        select(Series)
        .options(selectinload(Series.episodes))
        .where(Series.id == series_id)
    )
    series = res.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    if not series.is_published and (user is None or user.role != "admin"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    is_admin = user is not None and user.role == "admin"
    if not is_admin:
        series.episodes = [e for e in series.episodes if e.is_published]
    return series


@router.post("", response_model=SeriesOut, status_code=status.HTTP_201_CREATED)
async def create_series(
    payload: SeriesCreate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    series = Series(**payload.model_dump())
    db.add(series)
    await db.flush()
    await log_activity(db, admin, "create", "series", series.id, f"Created series '{series.title}'")
    await db.commit()
    await db.refresh(series)
    return series


@router.put("/{series_id}", response_model=SeriesOut)
async def update_series(
    series_id: int,
    payload: SeriesUpdate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Series).where(Series.id == series_id))
    series = res.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(series, k, v)
    await log_activity(db, admin, "update", "series", series.id, f"Updated series '{series.title}'")
    await db.commit()
    await db.refresh(series)
    return series


@router.delete("/{series_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_series(
    series_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Series).where(Series.id == series_id))
    series = res.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    series_title = series.title
    await db.delete(series)
    await log_activity(db, admin, "delete", "series", series_id, f"Deleted series '{series_title}'")
    await db.commit()
