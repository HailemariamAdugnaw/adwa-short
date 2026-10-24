from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def test_get_wallet(client, auth_headers):
    res = await client.get("/wallet", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["balance_birr"] == 100.0


async def test_deposit(client, auth_headers):
    res = await client.post(
        "/wallet/deposit",
        json={"amount_birr": 100, "provider": "telebirr"},
        headers=auth_headers,
    )
    assert res.status_code == 200
    assert res.json()["success"] is True
    assert res.json()["new_balance_birr"] == 200.0


async def test_coin_packages_empty(client):
    res = await client.get("/coins/packages")
    assert res.status_code == 200
    assert res.json() == []


async def test_admin_creates_coin_package(client, admin_headers):
    res = await client.post(
        "/coins/packages",
        json={"name": "Starter", "coins": 50, "price_birr": 50.0, "episodes_unlocked": 5},
        headers=admin_headers,
    )
    assert res.status_code == 201
    pkg_id = res.json()["id"]

    headers = await _auth_headers_with_balance(client, balance_birr=1000.0)
    purchase = await client.post(
        "/coins/purchase",
        json={"package_id": pkg_id},
        headers=headers,
    )
    assert purchase.status_code == 200
    assert purchase.json()["new_balance_coins"] == 50


async def _auth_headers_with_balance(client, balance_birr: float = 1000.0) -> dict:
    await client.post(
        "/auth/register",
        json={"phone": "+251933333333", "password": "pass1234"},
    )
    res = await client.post(
        "/auth/login",
        json={"phone": "+251933333333", "password": "pass1234"},
        headers={"X-Device-Id": "wallet-dev"},
    )
    token = res.json()["access_token"]

    from app.database import AsyncSessionLocal
    from app.models.user import User
    from app.models.wallet import Wallet
    from sqlalchemy import select

    async with AsyncSessionLocal() as s:
        u = (await s.execute(select(User).where(User.phone == "+251933333333"))).scalar_one()
        wres = await s.execute(select(Wallet).where(Wallet.user_id == u.id))
        wallet = wres.scalar_one_or_none()
        if wallet is None:
            wallet = Wallet(user_id=u.id, balance_birr=balance_birr, balance_coins=0)
            s.add(wallet)
        else:
            wallet.balance_birr = balance_birr
        await s.commit()
    return {"Authorization": f"Bearer {token}", "X-Device-Id": "wallet-dev"}


async def test_manual_deposit(client, admin_headers, demo_user):
    u, _ = demo_user
    res = await client.post(
        "/admin/wallet/manual-deposit",
        json={"user_id": u.id, "amount_birr": 200, "coins_credited": 50, "notes": "walk-in cash"},
        headers=admin_headers,
    )
    assert res.status_code == 201
    assert res.json()["amount_birr"] == 200.0

    bal = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": "user123"},
        headers={"X-Device-Id": "dev-manual"},
    )
    token = bal.json()["access_token"]
    w = await client.get("/wallet", headers={"Authorization": f"Bearer {token}"})
    assert w.json()["balance_birr"] == 300.0


async def test_manual_deposit_requires_admin(client, auth_headers, demo_user):
    u, _ = demo_user
    res = await client.post(
        "/admin/wallet/manual-deposit",
        json={"user_id": u.id, "amount_birr": 200},
        headers=auth_headers,
    )
    assert res.status_code == 403
