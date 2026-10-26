from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user, get_optional_user, get_settings_dict
from app.models.content import Episode, Series
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.content import EpisodeCreate, EpisodeOut, EpisodeUnlockOut, EpisodeUpdate
from app.services.monetization import (
    AccessDenied,
    get_effective_coin_cost,
    get_effective_free_episodes,
    resolve_access,
)
from app.services.audit import log_activity

router = APIRouter(prefix="/episodes", tags=["episodes"])


async def _enrich_episode_out(
    db: AsyncSession,
    ep: Episode,
    series: Series | None,
    user: User | None,
) -> EpisodeOut:
    if series is None:
        sres = await db.execute(select(Series).where(Series.id == ep.series_id))
        series = sres.scalar_one_or_none()

    is_free = False
    is_locked = True
    is_accessible = False

    if series is not None:
        effective_free = await get_effective_free_episodes(db, series)
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

    effective_coin_cost = 10
    if series is not None:
        effective_coin_cost = await get_effective_coin_cost(db, series, ep)

    data = EpisodeOut.model_validate(ep).model_dump()
    data["is_free"] = is_free
    data["is_locked"] = is_locked
    data["is_accessible"] = is_accessible
    data["effective_coin_cost"] = effective_coin_cost
    if data.get("coin_cost") is None or data.get("coin_cost") == 0:
        data["coin_cost"] = effective_coin_cost
    return EpisodeOut(**data)


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
    raw_eps = list(res.scalars().all())

    series_map: dict[int, Series] = {}
    if series_id is not None:
        sres = await db.execute(select(Series).where(Series.id == series_id))
        s_obj = sres.scalar_one_or_none()
        if s_obj is not None:
            series_map[series_id] = s_obj

    out: list[EpisodeOut] = []
    for ep in raw_eps:
        s = series_map.get(ep.series_id)
        out.append(await _enrich_episode_out(db, ep, s, user))
    return out


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
    return await _enrich_episode_out(db, ep, None, user)


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
    admin: User = Depends(get_current_admin),
):
    sres = await db.execute(select(Series).where(Series.id == payload.series_id))
    if sres.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    data = payload.model_dump()
    ep = Episode(**data)
    db.add(ep)
    await db.flush()
    await log_activity(
        db,
        admin,
        "create",
        "episode",
        ep.id,
        f"Created episode #{ep.episode_number} '{ep.title}' in series ID {ep.series_id}",
    )
    await db.commit()
    await db.refresh(ep)
    return ep


@router.put("/{episode_id}", response_model=EpisodeOut)
async def update_episode(
    episode_id: int,
    payload: EpisodeUpdate,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(ep, k, v)
    await log_activity(
        db,
        admin,
        "update",
        "episode",
        ep.id,
        f"Updated episode #{ep.episode_number} '{ep.title}'",
    )
    await db.commit()
    await db.refresh(ep)
    return ep


@router.delete("/{episode_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_admin),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    ep_title = ep.title
    ep_num = ep.episode_number
    await db.delete(ep)
    await log_activity(
        db,
        admin,
        "delete",
        "episode",
        episode_id,
        f"Deleted episode #{ep_num} '{ep_title}'",
    )
    await db.commit()


@router.post("/{episode_id}/unlock", response_model=EpisodeUnlockOut)
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

    wres_before = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet_before = wres_before.scalar_one_or_none()
    bal_before = wallet_before.balance_coins if wallet_before else 0

    try:
        await resolve_access(db, user, ep, series, deduct_coins=True)
    except AccessDenied as e:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=e.reason.value)
    await db.commit()

    wres_after = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet_after = wres_after.scalar_one_or_none()
    bal_after = wallet_after.balance_coins if wallet_after else 0
    coins_deducted = max(0, bal_before - bal_after)

    ep_data = EpisodeOut.model_validate(ep).model_dump()
    ep_data["is_free"] = False
    ep_data["is_locked"] = False
    ep_data["is_accessible"] = True

    return EpisodeUnlockOut(
        **ep_data,
        coins_deducted=coins_deducted,
        new_balance_coins=bal_after,
        message=f"Episode #{ep.episode_number} unlocked successfully. {coins_deducted} coins deducted.",
    )
