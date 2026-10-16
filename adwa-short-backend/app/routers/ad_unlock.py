from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.ad_unlock import AdUnlockLog, AdUnlockRule
from app.models.content import Episode
from app.models.user import User
from app.schemas.admin import AdUnlockLogCreate, AdUnlockLogOut, AdUnlockRuleOut, AdUnlockRuleUpdate
from app.services.monetization import can_use_ad_unlock, record_ad_unlock

router = APIRouter(prefix="/ad-unlocks", tags=["ad-unlocks"])


@router.get("/rule", response_model=AdUnlockRuleOut)
async def get_rule(db: AsyncSession = Depends(get_db)):
    res = await db.execute(select(AdUnlockRule).limit(1))
    rule = res.scalar_one_or_none()
    if rule is None:
        return AdUnlockRuleOut(
            id=0,
            ads_required=2,
            episodes_unlocked=1,
            is_active=True,
            updated_at=datetime.utcnow(),
        )
    return rule


@router.put("/rule", response_model=AdUnlockRuleOut)
async def update_rule(
    payload: AdUnlockRuleUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(AdUnlockRule).limit(1))
    rule = res.scalar_one_or_none()
    if rule is None:
        rule = AdUnlockRule(ads_required=2, episodes_unlocked=1, is_active=True)
        db.add(rule)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(rule, k, v)
    await db.commit()
    await db.refresh(rule)
    return rule


@router.post("/watched", response_model=AdUnlockLogOut, status_code=status.HTTP_201_CREATED)
async def watched_ad(
    payload: AdUnlockLogCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ep_res = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
    ep = ep_res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    allowed, rule = await can_use_ad_unlock(db, user.id, payload.episode_id)
    if not allowed or rule is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already unlocked or no rule configured")
    if payload.ads_watched < rule.ads_required:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Need to watch {rule.ads_required} ads (got {payload.ads_watched})",
        )
    log = await record_ad_unlock(db, user.id, payload.episode_id, payload.ads_watched)
    await db.commit()
    await db.refresh(log)
    return log
