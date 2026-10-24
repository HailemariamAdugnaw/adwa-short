from __future__ import annotations

import pytest
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.user import User
from app.models.wallet import CoinPurchase, Wallet

pytestmark = pytest.mark.asyncio


async def _register(client, phone: str) -> None:
    res = await client.post(
        "/auth/register",
        json={"phone": phone, "password": "pass1234"},
    )
    assert res.status_code == 201


async def _login(client, phone: str, device_id: str):
    return await client.post(
        "/auth/login",
        json={"phone": phone, "password": "pass1234"},
        headers={"X-Device-Id": device_id, "X-Platform": "android"},
    )


async def test_free_tier_bypasses_device_limit(client):
    phone = "+251960000001"
    await _register(client, phone)
    for i in range(1, 6):
        res = await _login(client, phone, f"dev-{i}")
        assert res.status_code == 200, f"device {i} failed: {res.text}"


async def test_free_tier_login_response_marks_unpaid(client):
    phone = "+251960000002"
    await _register(client, phone)
    res = await _login(client, phone, "dev-1")
    assert res.status_code == 200
    body = res.json()
    assert body["is_paid_tier"] is False
    assert body["device_limit_enforced"] is False


async def test_wallet_balance_triggers_device_limit(client):
    phone = "+251960000003"
    await _register(client, phone)
    await _login(client, phone, "dev-1")

    async with AsyncSessionLocal() as s:
        u = (await s.execute(select(User).where(User.phone == phone))).scalar_one()
        wres = await s.execute(select(Wallet).where(Wallet.user_id == u.id))
        wallet = wres.scalar_one_or_none()
        if wallet is None:
            wallet = Wallet(user_id=u.id, balance_birr=100.0, balance_coins=0)
            s.add(wallet)
        else:
            wallet.balance_birr = 100.0
        await s.commit()

    r2 = await _login(client, phone, "dev-2")
    assert r2.status_code == 200
    assert r2.json()["is_paid_tier"] is True

    r3 = await _login(client, phone, "dev-3")
    assert r3.status_code == 403
    assert r3.json()["detail"] == "MAX_DEVICE_LIMIT_REACHED"


async def test_coin_purchase_triggers_device_limit(client):
    phone = "+251960000004"
    await _register(client, phone)
    await _login(client, phone, "dev-1")

    async with AsyncSessionLocal() as s:
        u = (await s.execute(select(User).where(User.phone == phone))).scalar_one()
        s.add(CoinPurchase(user_id=u.id, package_id=None, coins=50, price_birr=50.0))
        await s.commit()

    r2 = await _login(client, phone, "dev-2")
    assert r2.status_code == 200
    r3 = await _login(client, phone, "dev-3")
    assert r3.status_code == 403


async def test_zero_wallet_balance_still_free_tier(client):
    phone = "+251960000005"
    await _register(client, phone)
    await _login(client, phone, "dev-1")
    res = await _login(client, phone, "dev-2")
    assert res.status_code == 200
    assert res.json()["is_paid_tier"] is False
