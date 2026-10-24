from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.loyalty import LoyaltyRewardConfig, LoyaltyRewardGrant
from app.models.user import User
from app.schemas.loyalty import LoyaltyConfigOut, LoyaltyConfigUpdate, LoyaltyGrantOut

router = APIRouter(prefix="/loyalty", tags=["loyalty"])


async def _get_or_create_config(db: AsyncSession) -> LoyaltyRewardConfig:
    res = await db.execute(select(LoyaltyRewardConfig).limit(1))
    cfg = res.scalar_one_or_none()
    if cfg is None:
        cfg = LoyaltyRewardConfig()
        db.add(cfg)
        await db.flush()
    return cfg


@router.get("/config", response_model=LoyaltyConfigOut)
async def get_config(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    return await _get_or_create_config(db)


@router.put("/config", response_model=LoyaltyConfigOut)
async def update_config(
    payload: LoyaltyConfigUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    cfg = await _get_or_create_config(db)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(cfg, k, v)
    await db.commit()
    await db.refresh(cfg)
    return cfg


@router.get("/my-grants", response_model=List[LoyaltyGrantOut])
async def my_grants(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(LoyaltyRewardGrant).where(LoyaltyRewardGrant.user_id == user.id).order_by(LoyaltyRewardGrant.granted_at.desc())
    )
    return list(res.scalars().all())


@router.get("/grants/{user_id}", response_model=List[LoyaltyGrantOut])
async def user_grants(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(
        select(LoyaltyRewardGrant).where(LoyaltyRewardGrant.user_id == user_id).order_by(LoyaltyRewardGrant.granted_at.desc())
    )
    return list(res.scalars().all())
