from __future__ import annotations

from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin
from app.models.admin import AuditLog
from app.models.content import Episode, Series
from app.models.revenue import Creator
from app.models.user import User
from app.schemas.content import EpisodeOut, SeriesOut

router = APIRouter(prefix="/admin/content", tags=["admin-content"])


async def _log(db: AsyncSession, admin: User, action: str, entity: str, entity_id: int | None, details: str | None = None) -> None:
    db.add(AuditLog(admin_id=admin.id, action=action, entity_type=entity, entity_id=entity_id, details=details))


async def _ensure_creator_binding(db: AsyncSession, creator_id: int | None) -> int:
    if creator_id is not None:
        c_res = await db.execute(select(Creator).where(Creator.id == creator_id))
        if c_res.scalar_one_or_none() is not None:
            return creator_id
    def_res = await db.execute(select(Creator).order_by(Creator.id).limit(1))
    c = def_res.scalar_one_or_none()
    if c is None:
        c = Creator(name="ADWA Platform Creator", default_revenue_split_pct=50.0, is_active=True)
        db.add(c)
        await db.flush()
    return c.id


@router.get("/unpublished", response_model=List[SeriesOut])
async def unpublished_series(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(Series).where(Series.is_published.is_(False)).order_by(desc(Series.created_at)))
    return list(res.scalars().all())


@router.post("/series/{series_id}/publish", response_model=SeriesOut)
async def publish_series(
    series_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Series).where(Series.id == series_id))
    s = res.scalar_one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    # Ownership Binding: Enforce that every published series is explicitly bound to a unique creator
    s.creator_id = await _ensure_creator_binding(db, s.creator_id)
    s.is_published = True
    await _log(db, admin, "publish", "series", s.id)
    await db.commit()
    await db.refresh(s)
    return s


@router.post("/series/{series_id}/unpublish", response_model=SeriesOut)
async def unpublish_series(
    series_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Series).where(Series.id == series_id))
    s = res.scalar_one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    s.is_published = False
    await _log(db, admin, "unpublish", "series", s.id)
    await db.commit()
    await db.refresh(s)
    return s


@router.post("/episodes/{episode_id}/publish", response_model=EpisodeOut)
async def publish_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    # Ownership Binding: Enforce that every published episode is explicitly bound to a unique creator
    if ep.creator_id is None:
        sres = await db.execute(select(Series).where(Series.id == ep.series_id))
        series = sres.scalar_one_or_none()
        inherited_id = series.creator_id if series else None
        ep.creator_id = await _ensure_creator_binding(db, inherited_id)
    else:
        ep.creator_id = await _ensure_creator_binding(db, ep.creator_id)
    ep.is_published = True
    if ep.published_at is None:
        ep.published_at = datetime.utcnow()
    await _log(db, admin, "publish", "episode", ep.id)
    await db.commit()
    await db.refresh(ep)
    return ep


@router.post("/episodes/{episode_id}/unpublish", response_model=EpisodeOut)
async def unpublish_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    ep.is_published = False
    await _log(db, admin, "unpublish", "episode", ep.id)
    await db.commit()
    await db.refresh(ep)
    return ep


@router.get("/audit", response_model=List[dict])
async def audit_logs(
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(AuditLog).order_by(desc(AuditLog.created_at)).limit(limit))
    out = []
    for a in res.scalars().all():
        out.append(
            {
                "id": a.id,
                "admin_id": a.admin_id,
                "action": a.action,
                "entity_type": a.entity_type,
                "entity_id": a.entity_id,
                "details": a.details,
                "created_at": a.created_at.isoformat(),
            }
        )
    return out


@router.post("/analytics/recompute")
async def recompute_scores(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    from app.services.analytics import recompute_popular_scores

    updated = await recompute_popular_scores(db)
    await db.commit()
    return {"updated_series": updated}
