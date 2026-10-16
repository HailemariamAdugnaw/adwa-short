from __future__ import annotations

from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Optional, Tuple

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ad_unlock import AdUnlockLog, AdUnlockRule
from app.models.content import Episode, Series
from app.models.subscription import Subscription, TimePassPurchase
from app.models.user import User
from app.models.wallet import Wallet


class AccessResult(str, Enum):
    FREE = "free"
    ALLOWED_AD = "allowed_ad"
    ALLOWED_PASS = "allowed_pass"
    ALLOWED_SUBSCRIPTION = "allowed_subscription"
    ALLOWED_COINS = "allowed_coins"
    BLOCKED_NEED_AD = "need_ad"
    BLOCKED_NEED_COINS = "need_coins"
    BLOCKED_NEED_PASS = "need_pass"
    BLOCKED_NEED_SUBSCRIPTION = "need_subscription"


class AccessDenied(Exception):
    def __init__(self, reason: AccessResult, episode_id: int) -> None:
        super().__init__(reason.value)
        self.reason = reason
        self.episode_id = episode_id


async def _has_ad_unlock(db: AsyncSession, user_id: int, episode_id: int) -> bool:
    res = await db.execute(
        select(AdUnlockLog).where(
            AdUnlockLog.user_id == user_id,
            AdUnlockLog.episode_id == episode_id,
        )
    )
    return res.scalar_one_or_none() is not None


async def _has_active_pass(db: AsyncSession, user_id: int) -> Tuple[bool, Optional[datetime]]:
    now = datetime.now(timezone.utc)
    res = await db.execute(
        select(TimePassPurchase).where(
            TimePassPurchase.user_id == user_id,
            TimePassPurchase.is_active.is_(True),
            TimePassPurchase.expires_at > now,
        ).order_by(TimePassPurchase.expires_at.desc()).limit(1)
    )
    p = res.scalar_one_or_none()
    if p is None:
        return False, None
    return True, p.expires_at


async def _has_active_subscription(db: AsyncSession, user_id: int) -> Tuple[bool, Optional[datetime]]:
    now = datetime.now(timezone.utc)
    res = await db.execute(
        select(Subscription).where(
            Subscription.user_id == user_id,
            Subscription.status == "active",
            Subscription.next_billing_at > now,
        ).order_by(Subscription.next_billing_at.desc()).limit(1)
    )
    s = res.scalar_one_or_none()
    if s is None:
        return False, None
    return True, s.next_billing_at


async def _get_ad_rule(db: AsyncSession) -> Optional[AdUnlockRule]:
    res = await db.execute(select(AdUnlockRule).where(AdUnlockRule.is_active.is_(True)).limit(1))
    return res.scalar_one_or_none()


async def resolve_access(
    db: AsyncSession,
    user: Optional[User],
    episode: Episode,
    series: Series,
    deduct_coins: bool = True,
) -> AccessResult:
    if episode.episode_number <= series.free_episode_count:
        return AccessResult.FREE

    if user is None:
        raise AccessDenied(AccessResult.BLOCKED_NEED_SUBSCRIPTION, episode.id)

    if await _has_ad_unlock(db, user.id, episode.id):
        return AccessResult.ALLOWED_AD

    has_pass, _ = await _has_active_pass(db, user.id)
    if has_pass:
        return AccessResult.ALLOWED_PASS

    has_sub, _ = await _has_active_subscription(db, user.id)
    if has_sub:
        return AccessResult.ALLOWED_SUBSCRIPTION

    if episode.coin_cost > 0:
        wres = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
        wallet = wres.scalar_one_or_none()
        if wallet is not None and wallet.balance_coins >= episode.coin_cost:
            if deduct_coins:
                wallet.balance_coins -= episode.coin_cost
                from app.models.wallet import WalletTransaction
                db.add(
                    WalletTransaction(
                        wallet_id=wallet.id,
                        type="purchase",
                        amount_birr=0,
                        amount_coins=-episode.coin_cost,
                        description=f"Unlocked episode {episode.id}",
                        reference=f"episode:{episode.id}",
                    )
                )
                await db.flush()
            return AccessResult.ALLOWED_COINS
        raise AccessDenied(AccessResult.BLOCKED_NEED_COINS, episode.id)

    raise AccessDenied(AccessResult.BLOCKED_NEED_SUBSCRIPTION, episode.id)


async def can_use_ad_unlock(db: AsyncSession, user_id: int, episode_id: int) -> Tuple[bool, Optional[AdUnlockRule]]:
    rule = await _get_ad_rule(db)
    if rule is None:
        return False, None
    already = await _has_ad_unlock(db, user_id, episode_id)
    if already:
        return False, rule
    return True, rule


async def record_ad_unlock(db: AsyncSession, user_id: int, episode_id: int, ads_watched: int) -> AdUnlockLog:
    log = AdUnlockLog(user_id=user_id, episode_id=episode_id, ads_watched=ads_watched)
    db.add(log)
    await db.flush()
    return log
