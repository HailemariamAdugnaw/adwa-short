from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.loyalty import LoyaltyRewardConfig, LoyaltyRewardGrant
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction


async def get_config(db: AsyncSession) -> Optional[LoyaltyRewardConfig]:
    res = await db.execute(
        select(LoyaltyRewardConfig).where(LoyaltyRewardConfig.is_active.is_(True)).limit(1)
    )
    return res.scalar_one_or_none()


async def maybe_grant(db: AsyncSession, user: User, wallet: Wallet) -> Optional[LoyaltyRewardGrant]:
    cfg = await get_config(db)
    if cfg is None:
        return None

    try:
        bal = float(wallet.balance_birr)
    except (TypeError, ValueError):
        return None

    if bal < float(cfg.min_balance_birr) or bal > float(cfg.max_balance_birr):
        return None

    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    res = await db.execute(
        select(LoyaltyRewardGrant).where(
            LoyaltyRewardGrant.user_id == user.id,
            LoyaltyRewardGrant.granted_at >= cutoff,
        ).limit(1)
    )
    if res.scalar_one_or_none() is not None:
        return None

    wallet.balance_coins = (wallet.balance_coins or 0) + int(cfg.free_coins)
    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="loyalty",
            amount_birr=0,
            amount_coins=int(cfg.free_coins),
            description="Loyalty reward",
            reference="loyalty",
        )
    )
    grant = LoyaltyRewardGrant(
        user_id=user.id,
        details={
            "free_coins": int(cfg.free_coins),
            "daily_access_days": int(cfg.daily_access_days),
            "free_full_series_count": int(cfg.free_full_series_count),
            "balance_birr_at_grant": bal,
        },
    )
    db.add(grant)
    await db.flush()
    return grant
