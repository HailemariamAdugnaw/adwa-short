from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional, Tuple

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.subscription import Subscription, TimePassPurchase
from app.models.user import Device, User
from app.models.wallet import CoinPurchase, Wallet
from app.utils.time import utcnow


class DeviceLimitError(Exception):
    def __init__(self, message: str = "MAX_DEVICE_LIMIT_REACHED", code: str = "MAX_DEVICE_LIMIT_REACHED") -> None:
        super().__init__(message)
        self.code = code


class FreeTierBypass(Exception):
    def __init__(self, message: str = "FREE_TIER_DEVICE_LIMIT_BYPASS") -> None:
        super().__init__(message)
        self.code = "FREE_TIER_DEVICE_LIMIT_BYPASS"


async def count_active_devices(db: AsyncSession, user_id: int) -> int:
    result = await db.execute(
        select(func.count(Device.id)).where(Device.user_id == user_id, Device.is_active.is_(True))
    )
    return int(result.scalar_one())


async def is_paid_tier(db: AsyncSession, user_id: int) -> bool:
    now = datetime.now(timezone.utc)

    sub_res = await db.execute(
        select(Subscription).where(
            Subscription.user_id == user_id,
            Subscription.status == "active",
            Subscription.next_billing_at > now,
        ).limit(1)
    )
    if sub_res.scalar_one_or_none() is not None:
        return True

    pass_res = await db.execute(
        select(TimePassPurchase).where(
            TimePassPurchase.user_id == user_id,
            TimePassPurchase.is_active.is_(True),
            TimePassPurchase.expires_at > now,
        ).limit(1)
    )
    if pass_res.scalar_one_or_none() is not None:
        return True

    w_res = await db.execute(select(Wallet).where(Wallet.user_id == user_id))
    wallet = w_res.scalar_one_or_none()
    if wallet is not None:
        if float(wallet.balance_birr or 0) > 0 or int(wallet.balance_coins or 0) > 0:
            return True

    cp_res = await db.execute(
        select(CoinPurchase).where(CoinPurchase.user_id == user_id).limit(1)
    )
    if cp_res.scalar_one_or_none() is not None:
        return True

    return False


async def register_or_touch_device(
    db: AsyncSession,
    user: User,
    device_fingerprint: str,
    device_name: Optional[str],
    platform: str,
    max_devices: int,
) -> Tuple[Device, bool]:
    result = await db.execute(
        select(Device).where(
            Device.user_id == user.id,
            Device.device_fingerprint == device_fingerprint,
        )
    )
    device = result.scalar_one_or_none()

    if device is not None:
        device.last_seen = utcnow()
        device.is_active = True
        if device_name:
            device.device_name = device_name
        device.platform = platform or device.platform
        await db.flush()
        return device, False

    paid = await is_paid_tier(db, user.id)
    if not paid:
        active_count = await count_active_devices(db, user.id)
        device = Device(
            user_id=user.id,
            device_fingerprint=device_fingerprint,
            device_name=device_name,
            platform=platform,
            last_seen=utcnow(),
            is_active=True,
        )
        db.add(device)
        await db.flush()
        return device, True

    active_count = await count_active_devices(db, user.id)
    if active_count >= max_devices:
        raise DeviceLimitError()

    device = Device(
        user_id=user.id,
        device_fingerprint=device_fingerprint,
        device_name=device_name,
        platform=platform,
        last_seen=utcnow(),
        is_active=True,
    )
    db.add(device)
    await db.flush()
    return device, True
