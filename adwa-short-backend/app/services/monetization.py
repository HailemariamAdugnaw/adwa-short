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


async def _has_coin_unlock(db: AsyncSession, user_id: int, episode_id: int) -> bool:
    from app.models.wallet import WalletTransaction
    res = await db.execute(
        select(WalletTransaction)
        .join(Wallet, Wallet.id == WalletTransaction.wallet_id)
        .where(
            Wallet.user_id == user_id,
            WalletTransaction.type == "purchase",
            WalletTransaction.reference == f"episode:{episode_id}",
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
    res = await db.execute(select(AdUnlockRule).limit(1))
    rule = res.scalar_one_or_none()
    if rule is None:
        from app.config import settings
        rule = AdUnlockRule(
            ads_required=settings.AD_ADS_REQUIRED,
            episodes_unlocked=settings.AD_EPISODES_UNLOCKED,
            is_active=settings.AD_ENABLED,
            provider=settings.AD_NETWORK_PROVIDER,
            app_id=settings.AD_NETWORK_APP_ID,
            banner_unit_id=settings.AD_BANNER_UNIT_ID,
            interstitial_unit_id=settings.AD_INTERSTITIAL_UNIT_ID,
            rewarded_unit_id=settings.AD_REWARDED_UNIT_ID,
            api_key=settings.AD_NETWORK_API_KEY,
            callback_secret=settings.AD_REWARD_CALLBACK_SECRET,
            test_mode=settings.AD_TEST_MODE,
        )
        db.add(rule)
        await db.flush()
    return rule


async def get_effective_free_episodes(
    db: AsyncSession,
    series: Series,
    settings_dict: Optional[dict] = None,
) -> int:
    """
    Hierarchical resolution:
    1. If series.free_episode_count is explicitly set (e.g. 0, 1, 5), use it as series override.
    2. Otherwise (series.free_episode_count is None), fall back to global AppSettings 'free_trial_default_episodes' (default 3).
    """
    if series.free_episode_count is not None:
        return max(0, int(series.free_episode_count))
    if settings_dict is None:
        from app.deps import get_settings_dict
        settings_dict = await get_settings_dict(db)
    try:
        return max(0, int(settings_dict.get("free_trial_default_episodes", "3")))
    except (TypeError, ValueError):
        return 3


async def get_effective_coin_cost(
    db: AsyncSession,
    series: Series,
    episode: Optional[Episode] = None,
    settings_dict: Optional[dict] = None,
) -> int:
    """
    Hierarchical resolution:
    1. If episode.coin_cost is explicitly set (> 0), use it.
    2. Else if series.coin_cost is explicitly set (> 0), use it as series-level override.
    3. Otherwise, fall back to global AppSettings 'default_episode_coin_cost' (default 10).
    """
    if episode is not None and episode.coin_cost is not None and episode.coin_cost > 0:
        return int(episode.coin_cost)
    if series is not None and getattr(series, "coin_cost", None) is not None and series.coin_cost > 0:
        return int(series.coin_cost)
    if settings_dict is None:
        from app.deps import get_settings_dict
        settings_dict = await get_settings_dict(db)
    try:
        return max(1, int(settings_dict.get("default_episode_coin_cost", "10")))
    except (TypeError, ValueError):
        return 10


async def resolve_access(
    db: AsyncSession,
    user: Optional[User],
    episode: Episode,
    series: Series,
    deduct_coins: bool = True,
) -> AccessResult:
    from app.deps import get_settings_dict
    sd = await get_settings_dict(db)
    effective_free = await get_effective_free_episodes(db, series, sd)

    if episode.episode_number <= effective_free:
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

    if await _has_coin_unlock(db, user.id, episode.id):
        return AccessResult.ALLOWED_COINS

    # Effective coin cost resolution
    effective_coin_cost = await get_effective_coin_cost(db, series, episode, sd)

    wres = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet = wres.scalar_one_or_none()
    if wallet is not None and wallet.balance_coins >= effective_coin_cost:
        if deduct_coins:
            wallet.balance_coins -= effective_coin_cost
            from app.models.wallet import WalletTransaction
            db.add(
                WalletTransaction(
                    wallet_id=wallet.id,
                    type="purchase",
                    amount_birr=0,
                    amount_coins=-effective_coin_cost,
                    description=f"Unlocked episode {episode.id}",
                    reference=f"episode:{episode.id}",
                )
            )
            await db.flush()
            return AccessResult.ALLOWED_COINS

    raise AccessDenied(AccessResult.BLOCKED_NEED_COINS, episode.id)


async def can_use_ad_unlock(db: AsyncSession, user_id: int, episode_id: int) -> Tuple[bool, Optional[AdUnlockRule]]:
    rule = await _get_ad_rule(db)
    if rule is None or not rule.is_active:
        return False, rule
    already = await _has_ad_unlock(db, user_id, episode_id)
    if already:
        return False, rule
    return True, rule


async def record_ad_unlock(
    db: AsyncSession,
    user_id: int,
    episode_id: int,
    ads_watched: int,
    ad_network: Optional[str] = "admob",
    verified_via: str = "client",
    revenue_birr: Optional[float] = None,
) -> AdUnlockLog:
    val = round(float(revenue_birr), 4) if (revenue_birr is not None and revenue_birr > 0) else 0.0
    log = AdUnlockLog(
        user_id=user_id,
        episode_id=episode_id,
        ads_watched=ads_watched,
        ad_network=ad_network or "admob",
        verified_via=verified_via,
        revenue_birr=val,
    )
    db.add(log)
    await db.flush()
    return log
