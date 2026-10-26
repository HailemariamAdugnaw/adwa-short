from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.deps import get_current_admin, get_optional_user, get_settings_dict
from app.models.content import Episode, Series
from app.models.user import User
from app.schemas.content import EpisodeOut, SeriesCreate, SeriesDetailOut, SeriesOut, SeriesUpdate
from app.services.audit import log_activity
from app.services.monetization import (
    AccessDenied,
    get_effective_coin_cost,
    get_effective_free_episodes,
    resolve_access,
)

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
    raw_series = list(res.scalars().all())
    sd = await get_settings_dict(db)
    out: list[SeriesOut] = []
    for s in raw_series:
        eff_free = await get_effective_free_episodes(db, s, sd)
        eff_coin = await get_effective_coin_cost(db, s, None, sd)
        s_data = SeriesOut.model_validate(s).model_dump()
        s_data["effective_free_episodes"] = eff_free
        s_data["free_episodes"] = s.free_episode_count
        s_data["free_episode_count"] = s.free_episode_count
        s_data["effective_coin_cost"] = eff_coin
        s_data["coin_cost"] = s.coin_cost
        out.append(SeriesOut(**s_data))
    return out


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
    raw_episodes = series.episodes if is_admin else [e for e in series.episodes if e.is_published]

    sd = await get_settings_dict(db)
    effective_free = await get_effective_free_episodes(db, series, sd)

    enriched_episodes: list[EpisodeOut] = []
    for ep in raw_episodes:
        if ep.episode_number <= effective_free:
            is_free = True
            is_locked = False
            is_accessible = True
        else:
            is_free = False
            if user is not None:
                try:
                    await resolve_access(db, user, ep, series, deduct_coins=False)
                    is_locked = False
                    is_accessible = True
                except AccessDenied:
                    is_locked = True
                    is_accessible = False
            else:
                is_locked = True
                is_accessible = False
        ep_dict = EpisodeOut.model_validate(ep).model_dump()
        ep_dict["is_free"] = is_free
        ep_dict["is_locked"] = is_locked
        ep_dict["is_accessible"] = is_accessible
        eff_ep_cost = await get_effective_coin_cost(db, series, ep, sd)
        ep_dict["effective_coin_cost"] = eff_ep_cost
        if ep_dict.get("coin_cost") is None or ep_dict.get("coin_cost") == 0:
            ep_dict["coin_cost"] = eff_ep_cost
        enriched_episodes.append(EpisodeOut(**ep_dict))

    eff_series_coin = await get_effective_coin_cost(db, series, None, sd)
    series_dict = SeriesOut.model_validate(series).model_dump()
    series_dict["effective_free_episodes"] = effective_free
    series_dict["free_episodes"] = series.free_episode_count
    series_dict["free_episode_count"] = series.free_episode_count
    series_dict["effective_coin_cost"] = eff_series_coin
    series_dict["coin_cost"] = series.coin_cost
    return SeriesDetailOut(**series_dict, episodes=enriched_episodes)


@router.post("", response_model=SeriesOut, status_code=status.HTTP_201_CREATED)
async def create_series(
    payload: SeriesCreate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    data = payload.model_dump()
    if "free_episodes" in data and data.get("free_episode_count") is None:
        data["free_episode_count"] = data["free_episodes"]
    series_columns = {c.key for c in Series.__table__.columns}
    filtered_data = {k: v for k, v in data.items() if k in series_columns}
    series = Series(**filtered_data)
    db.add(series)
    await db.flush()
    await log_activity(db, admin, "create", "series", series.id, f"Created series '{series.title}'")
    await db.commit()
    await db.refresh(series)
    sd = await get_settings_dict(db)
    eff_free = await get_effective_free_episodes(db, series, sd)
    eff_coin = await get_effective_coin_cost(db, series, None, sd)
    s_data = SeriesOut.model_validate(series).model_dump()
    s_data["effective_free_episodes"] = eff_free
    s_data["free_episodes"] = series.free_episode_count
    s_data["free_episode_count"] = series.free_episode_count
    s_data["effective_coin_cost"] = eff_coin
    s_data["coin_cost"] = series.coin_cost
    return SeriesOut(**s_data)


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
    data = payload.model_dump(exclude_unset=True)
    if "free_episodes" in data and "free_episode_count" not in data:
        data["free_episode_count"] = data["free_episodes"]
    series_columns = {c.key for c in Series.__table__.columns}
    for k, v in data.items():
        if k in series_columns:
            setattr(series, k, v)
    await log_activity(db, admin, "update", "series", series.id, f"Updated series '{series.title}'")
    await db.commit()
    await db.refresh(series)
    sd = await get_settings_dict(db)
    eff_free = await get_effective_free_episodes(db, series, sd)
    eff_coin = await get_effective_coin_cost(db, series, None, sd)
    s_data = SeriesOut.model_validate(series).model_dump()
    s_data["effective_free_episodes"] = eff_free
    s_data["free_episodes"] = series.free_episode_count
    s_data["free_episode_count"] = series.free_episode_count
    s_data["effective_coin_cost"] = eff_coin
    s_data["coin_cost"] = series.coin_cost
    return SeriesOut(**s_data)


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
