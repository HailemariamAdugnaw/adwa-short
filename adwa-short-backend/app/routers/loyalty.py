from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.loyalty import LoyaltyRewardConfig, LoyaltyRewardGrant
from app.models.subscription import TimePass, TimePassPurchase
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction
from app.schemas.loyalty import (
    LoyaltyClaimOut,
    LoyaltyConfigOut,
    LoyaltyConfigUpdate,
    LoyaltyGrantOut,
    LoyaltyStatusOut,
)

router = APIRouter(prefix="/loyalty", tags=["loyalty"])


async def _get_or_create_config(db: AsyncSession) -> LoyaltyRewardConfig:
    res = await db.execute(select(LoyaltyRewardConfig).limit(1))
    cfg = res.scalar_one_or_none()
    if cfg is None:
        cfg = LoyaltyRewardConfig()
        db.add(cfg)
        await db.flush()
    return cfg


async def _get_or_create_wallet(db: AsyncSession, user_id: int) -> Wallet:
    res = await db.execute(select(Wallet).where(Wallet.user_id == user_id))
    wallet = res.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user_id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()
    return wallet


@router.get("/config", response_model=LoyaltyConfigOut)
async def get_config(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """
    Returns active Super Admin loyalty program configuration.
    Accessible to all authenticated users and admins.
    """
    return await _get_or_create_config(db)


@router.put("/config", response_model=LoyaltyConfigOut)
async def update_config(
    payload: LoyaltyConfigUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    """Super Admin only: Update loyalty rules, thresholds, and perks."""
    cfg = await _get_or_create_config(db)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(cfg, k, v)
    await db.commit()
    await db.refresh(cfg)
    return cfg


@router.get("/status", response_model=LoyaltyStatusOut)
async def get_loyalty_status(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Evaluates the logged-in user's qualification and progress
    against the active Super Admin loyalty configuration.
    Enforces check if the user has already claimed the active reward tier.
    """
    cfg = await _get_or_create_config(db)
    wallet = await _get_or_create_wallet(db, user.id)

    b_birr = float(wallet.balance_birr or 0)
    b_coins = int(wallet.balance_coins or 0)
    min_b = float(cfg.min_balance_birr)
    max_b = float(cfg.max_balance_birr)

    # Check if user has already claimed this specific reward_id
    existing_grant = await db.execute(
        select(LoyaltyRewardGrant).where(
            LoyaltyRewardGrant.user_id == user.id,
            LoyaltyRewardGrant.reward_id == cfg.id,
        )
    )
    is_claimed = existing_grant.scalar_one_or_none() is not None

    qualifies = cfg.is_active and (b_birr >= min_b)
    needed = max(0.0, min_b - b_birr)
    progress = min(100.0, round((b_birr / min_b * 100.0), 1)) if min_b > 0 else 100.0
    can_claim = qualifies and not is_claimed

    return LoyaltyStatusOut(
        min_balance_birr=min_b,
        max_balance_birr=max_b,
        daily_access_days=cfg.daily_access_days,
        free_coins=cfg.free_coins,
        free_full_series_count=cfg.free_full_series_count,
        is_active=cfg.is_active,
        wallet_balance_birr=b_birr,
        wallet_balance_coins=b_coins,
        qualifies=qualifies,
        needed_birr=round(needed, 2),
        progress_pct=progress,
        can_claim=can_claim,
        reward_id=cfg.id,
        is_claimed=is_claimed,
    )


@router.post("/claim", response_model=LoyaltyClaimOut)
async def claim_loyalty_reward(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Claims loyalty rewards for users meeting the Super Admin's wallet balance threshold.
    Credits configured free coins and grants daily access passes.
    Strictly verifies each specific reward can only be claimed once per user.
    """
    cfg = await _get_or_create_config(db)
    if not cfg.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Loyalty reward program is currently inactive",
        )

    # 1. Strict validation: Block duplicate claims
    existing_claim = await db.execute(
        select(LoyaltyRewardGrant).where(
            LoyaltyRewardGrant.user_id == user.id,
            LoyaltyRewardGrant.reward_id == cfg.id,
        )
    )
    if existing_claim.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already claimed this loyalty reward. Each reward can only be claimed once.",
        )

    wallet = await _get_or_create_wallet(db, user.id)
    b_birr = float(wallet.balance_birr or 0)
    min_b = float(cfg.min_balance_birr)

    if b_birr < min_b:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Wallet balance ({b_birr:.2f} Birr) is below the minimum required ({min_b:.2f} Birr) for loyalty perks.",
        )

    # 2. Credit free coins to user wallet
    coins_to_add = cfg.free_coins
    wallet.balance_coins += coins_to_add
    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="loyalty_reward",
            amount_birr=0,
            amount_coins=coins_to_add,
            description="Super Admin Loyalty Tier Coin Reward",
            reference=f"loyalty:user:{user.id}:reward:{cfg.id}",
        )
    )

    # 3. Grant free daily access pass if configured
    if cfg.daily_access_days > 0:
        # Resolve or create a default pass record
        p_res = await db.execute(select(TimePass).where(TimePass.is_active.is_(True)).limit(1))
        t_pass = p_res.scalar_one_or_none()
        if t_pass is None:
            t_pass = TimePass(
                name="Loyalty Pass",
                duration_hours=cfg.daily_access_days * 24,
                price_birr=0,
                is_active=True,
            )
            db.add(t_pass)
            await db.flush()

        now = datetime.now(timezone.utc)
        expires = now + timedelta(days=cfg.daily_access_days)
        db.add(
            TimePassPurchase(
                user_id=user.id,
                pass_id=t_pass.id,
                starts_at=now,
                expires_at=expires,
                is_active=True,
            )
        )

    # 4. Insert audit grant log with reward_id
    grant = LoyaltyRewardGrant(
        user_id=user.id,
        reward_id=cfg.id,
        details={
            "title": "Loyalty Tier Reward",
            "type": "coins",
            "reward_id": cfg.id,
            "coins": coins_to_add,
            "daily_access_days": cfg.daily_access_days,
            "free_full_series_count": cfg.free_full_series_count,
            "description": f"Granted {coins_to_add} free coins and {cfg.daily_access_days} days access",
            "claimed_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    db.add(grant)

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already claimed this loyalty reward. Each reward can only be claimed once.",
        )

    return LoyaltyClaimOut(
        status="success",
        message=f"Successfully claimed {coins_to_add} coins and {cfg.daily_access_days} days access!",
        coins_awarded=coins_to_add,
        days_access_awarded=cfg.daily_access_days,
        free_series_awarded=cfg.free_full_series_count,
        new_balance_coins=wallet.balance_coins,
        reward_id=cfg.id,
        is_claimed=True,
    )


@router.post("/ad-bonus", response_model=LoyaltyClaimOut)
async def claim_ad_loyalty_bonus(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """
    Grants a loyalty streak ad bonus to users who engage with rewarded ads.
    """
    cfg = await _get_or_create_config(db)
    wallet = await _get_or_create_wallet(db, user.id)

    # Bonus coins from ad streak: e.g. 5 coins or fraction of free_coins
    bonus_coins = max(5, int(cfg.free_coins * 0.1)) if cfg.free_coins > 0 else 5
    wallet.balance_coins += bonus_coins

    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="ad_loyalty_bonus",
            amount_birr=0,
            amount_coins=bonus_coins,
            description="Rewarded Ad Loyalty Streak Bonus",
            reference=f"ad_loyalty:user:{user.id}:{datetime.now(timezone.utc).timestamp()}",
        )
    )

    grant = LoyaltyRewardGrant(
        user_id=user.id,
        details={
            "title": "Ad Watch Loyalty Bonus",
            "type": "coins",
            "coins": bonus_coins,
            "description": f"Earned {bonus_coins} bonus coins for watching rewarded ads",
            "claimed_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    db.add(grant)
    await db.commit()

    return LoyaltyClaimOut(
        status="success",
        message=f"Claimed {bonus_coins} loyalty bonus coins!",
        coins_awarded=bonus_coins,
        days_access_awarded=0,
        free_series_awarded=0,
        new_balance_coins=wallet.balance_coins,
    )


@router.get("/my-grants", response_model=List[LoyaltyGrantOut])
async def my_grants(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(LoyaltyRewardGrant)
        .where(LoyaltyRewardGrant.user_id == user.id)
        .order_by(desc(LoyaltyRewardGrant.granted_at))
    )
    return list(res.scalars().all())


@router.get("/grants/{user_id}", response_model=List[LoyaltyGrantOut])
async def user_grants(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(
        select(LoyaltyRewardGrant)
        .where(LoyaltyRewardGrant.user_id == user_id)
        .order_by(desc(LoyaltyRewardGrant.granted_at))
    )
    return list(res.scalars().all())
