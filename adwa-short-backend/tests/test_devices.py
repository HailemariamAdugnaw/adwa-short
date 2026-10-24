from __future__ import annotations

import pytest

from app.database import AsyncSessionLocal
from app.models.user import User
from app.models.wallet import Wallet
from sqlalchemy import select

pytestmark = pytest.mark.asyncio


async def _register_and_login(client, phone: str, device_id: str):
    await client.post(
        "/auth/register",
        json={"phone": phone, "password": "pass1234"},
    )
    res = await client.post(
        "/auth/login",
        json={"phone": phone, "password": "pass1234"},
        headers={"X-Device-Id": device_id, "X-Platform": "android"},
    )
    return res


async def _fund_wallet(phone: str, balance_birr: float = 100.0):
    async with AsyncSessionLocal() as s:
        u = (await s.execute(select(User).where(User.phone == phone))).scalar_one()
        wres = await s.execute(select(Wallet).where(Wallet.user_id == u.id))
        wallet = wres.scalar_one_or_none()
        if wallet is None:
            wallet = Wallet(user_id=u.id, balance_birr=balance_birr, balance_coins=0)
            s.add(wallet)
        else:
            wallet.balance_birr = balance_birr
        await s.commit()


async def test_first_device_login_ok(client):
    res = await _register_and_login(client, "+251944444444", "dev-1")
    assert res.status_code == 200


async def test_second_device_login_ok(client):
    await _register_and_login(client, "+251944444444", "dev-1")
    res = await _register_and_login(client, "+251944444444", "dev-2")
    assert res.status_code == 200


async def test_third_device_login_blocked(client):
    await _register_and_login(client, "+251944444444", "dev-1")
    await _fund_wallet("+251944444444", balance_birr=100.0)
    await _register_and_login(client, "+251944444444", "dev-2")
    res = await _register_and_login(client, "+251944444444", "dev-3")
    assert res.status_code == 403
    assert res.json()["detail"] == "MAX_DEVICE_LIMIT_REACHED"


async def test_same_device_repeat_login_ok(client):
    await _register_and_login(client, "+251944444444", "dev-1")
    await _register_and_login(client, "+251944444444", "dev-1")
    res = await _register_and_login(client, "+251944444444", "dev-1")
    assert res.status_code == 200


async def test_list_and_delete_device(client):
    await _register_and_login(client, "+251944444444", "dev-1")
    login = await _register_and_login(client, "+251944444444", "dev-1")
    token = login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}", "X-Device-Id": "dev-1"}

    res = await client.get("/devices", headers=headers)
    assert res.status_code == 200
    assert len(res.json()) == 1

    dev_id = res.json()[0]["id"]
    delete_res = await client.delete(f"/devices/{dev_id}", headers=headers)
    assert delete_res.status_code == 204

    res2 = await client.get("/devices", headers=headers)
    assert res2.json() == []
