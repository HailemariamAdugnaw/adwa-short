from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_settings_dict
from app.models.ad_unlock import AdUnlockRule
from app.models.settings import AppSettings
from app.models.user import User
from app.schemas.settings import PublicSettings, SettingOut, SettingUpdate

router = APIRouter(prefix="/settings", tags=["settings"])


def _to_int(v: str, default: int) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def _to_float(v: str, default: float) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _to_bool(v: str, default: bool) -> bool:
    return str(v).strip().lower() in {"1", "true", "yes", "on"}


@router.get("/public", response_model=PublicSettings)
async def public_settings(db: AsyncSession = Depends(get_db)):
    sd = await get_settings_dict(db)
    rule_res = await db.execute(select(AdUnlockRule).limit(1))
    rule = rule_res.scalar_one_or_none()
    return PublicSettings(
        maintenance_mode=_to_bool(sd.get("maintenance_mode", "false"), False),
        free_trial_default_episodes=_to_int(sd.get("free_trial_default_episodes", "3"), 3),
        max_devices_per_account=_to_int(sd.get("max_devices_per_account", "2"), 2),
        coin_price_birr=_to_float(sd.get("coin_price_birr", "1.0"), 1.0),
        ad_unlock_ads_required=int(rule.ads_required) if rule else 2,
        ad_unlock_episodes_unlocked=int(rule.episodes_unlocked) if rule else 1,
    )


@router.get("", response_model=List[SettingOut])
async def list_all_settings(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(AppSettings).order_by(AppSettings.key))
    return list(res.scalars().all())


@router.put("/{key}", response_model=SettingOut)
async def update_setting(
    key: str,
    payload: SettingUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(AppSettings).where(AppSettings.key == key))
    s = res.scalar_one_or_none()
    if s is None:
        s = AppSettings(key=key, value=payload.value, description=payload.description or "")
        db.add(s)
    else:
        s.value = payload.value
        if payload.description is not None:
            s.description = payload.description
    await db.commit()
    await db.refresh(s)
    return s


@router.get("/{key}")
async def get_setting(key: str, db: AsyncSession = Depends(get_db)):
    res = await db.execute(select(AppSettings).where(AppSettings.key == key))
    s = res.scalar_one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Setting not found")
    return {"key": s.key, "value": s.value, "description": s.description}
