from __future__ import annotations

import pytest

pytestmark = pytest.mark.asyncio


async def test_register(client):
    res = await client.post(
        "/auth/register",
        json={"phone": "+251922222222", "password": "pass1234", "display_name": "New User"},
    )
    assert res.status_code == 201, res.text
    data = res.json()
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["role"] == "user"


async def test_register_duplicate(client, demo_user):
    u, pwd = demo_user
    res = await client.post(
        "/auth/register",
        json={"phone": u.phone, "password": pwd},
    )
    assert res.status_code == 409


async def test_login_success(client, demo_user):
    u, pwd = demo_user
    res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": pwd},
        headers={"X-Device-Id": "dev-1"},
    )
    assert res.status_code == 200
    assert res.json()["access_token"]


async def test_login_wrong_password(client, demo_user):
    u, _ = demo_user
    res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": "wrong"},
        headers={"X-Device-Id": "dev-1"},
    )
    assert res.status_code == 401


async def test_login_missing_device_header(client, demo_user):
    u, pwd = demo_user
    res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": pwd},
    )
    assert res.status_code == 422


async def test_refresh(client, demo_user):
    u, pwd = demo_user
    login_res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": pwd},
        headers={"X-Device-Id": "dev-refresh"},
    )
    refresh_token = login_res.json()["refresh_token"]
    res = await client.post("/auth/refresh", json={"refresh_token": refresh_token})
    assert res.status_code == 200
    assert res.json()["access_token"]


async def test_me(client, auth_headers):
    res = await client.get("/users/me", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["phone"] == "+251911111111"
