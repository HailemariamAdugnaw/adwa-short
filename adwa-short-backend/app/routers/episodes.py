from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user, get_optional_user
from app.models.content import Episode, Series
from app.models.user import User
from app.schemas.content import EpisodeCreate, EpisodeOut, EpisodeUpdate
from app.services.monetization import AccessDenied, resolve_access

router = APIRouter(prefix="/episodes", tags=["episodes"])


@router.get("", response_model=list[EpisodeOut])
async def list_episodes(
    series_id: int | None = Query(default=None),
    is_short: bool | None = Query(default=None),
    limit: int = Query(default=50, le=200),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_optional_user),
):
    is_admin = user is not None and user.role == "admin"
    stmt = select(Episode)
    if series_id is not None:
        stmt = stmt.where(Episode.series_id == series_id)
    if is_short is not None:
        stmt = stmt.where(Episode.is_short.is_(is_short))
    if not is_admin:
        stmt = stmt.where(Episode.is_published.is_(True))
    stmt = stmt.order_by(Episode.created_at.desc()).limit(limit).offset(offset)
    res = await db.execute(stmt)
    return list(res.scalars().all())


@router.get("/{episode_id}", response_model=EpisodeOut)
async def get_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_optional_user),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    is_admin = user is not None and user.role == "admin"
    if not ep.is_published and not is_admin:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    return ep


@router.get("/{episode_id}/access")
async def check_access(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_optional_user),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    sres = await db.execute(select(Series).where(Series.id == ep.series_id))
    series = sres.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    try:
        result = await resolve_access(db, user, ep, series, deduct_coins=False)
    except AccessDenied as e:
        return {"access": "denied", "reason": e.reason.value, "episode_id": episode_id}
    return {"access": "allowed", "method": result.value, "episode_id": episode_id}


@router.post("", response_model=EpisodeOut, status_code=status.HTTP_201_CREATED)
async def create_episode(
    payload: EpisodeCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    sres = await db.execute(select(Series).where(Series.id == payload.series_id))
    if sres.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    data = payload.model_dump()
    ep = Episode(**data)
    db.add(ep)
    await db.commit()
    await db.refresh(ep)
    return ep


@router.put("/{episode_id}", response_model=EpisodeOut)
async def update_episode(
    episode_id: int,
    payload: EpisodeUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(ep, k, v)
    await db.commit()
    await db.refresh(ep)
    return ep


@router.delete("/{episode_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    await db.delete(ep)
    await db.commit()


@router.post("/{episode_id}/unlock", response_model=EpisodeOut)
async def unlock_with_coins(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    sres = await db.execute(select(Series).where(Series.id == ep.series_id))
    series = sres.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    try:
        await resolve_access(db, user, ep, series, deduct_coins=True)
    except AccessDenied as e:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=e.reason.value)
    await db.commit()
    return ep
