from __future__ import annotations

import asyncio
import os
import sys
from typing import AsyncIterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "sqlite+aiosqlite:///:memory:",
)
os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ["JWT_SECRET"] = "test-secret"
os.environ.setdefault("MAX_DEVICES_PER_ACCOUNT", "2")

from app.database import Base, AsyncSessionLocal, engine, get_db
import app.models
from app.main import app
from app.models.admin import AdminUser
from app.models.user import User
from app.models.wallet import Wallet
from app.security import hash_password


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def db_session() -> AsyncIterator:
    async with AsyncSessionLocal() as s:
        yield s


async def _override_get_db():
    async with AsyncSessionLocal() as s:
        try:
            yield s
        finally:
            await s.close()


app.dependency_overrides[get_db] = _override_get_db


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _create_user(
    phone: str = "+251911111111",
    password: str = "user123",
    role: str = "user",
    balance_birr: float = 100.0,
    balance_coins: int = 50,
) -> tuple[User, str]:
    async with AsyncSessionLocal() as s:
        u = User(
            phone=phone,
            password_hash=hash_password(password),
            display_name=phone[-4:],
            role=role,
            is_active=True,
        )
        s.add(u)
        await s.flush()
        s.add(Wallet(user_id=u.id, balance_birr=balance_birr, balance_coins=balance_coins))
        if role in ("admin", "super_admin"):
            s.add(AdminUser(user_id=u.id, role_label="super_admin", permissions="*"))
        elif role == "staff":
            s.add(AdminUser(user_id=u.id, role_label="staff", permissions="content"))
        await s.commit()
        await s.refresh(u)
        return u, password


@pytest_asyncio.fixture
async def demo_user():
    return await _create_user("+251911111111", "user123", "user")


@pytest_asyncio.fixture
async def admin_user():
    return await _create_user("+251900000000", "admin123", "admin")


@pytest_asyncio.fixture
async def staff_user():
    return await _create_user("+251922222222", "staff123", "staff")


@pytest_asyncio.fixture
async def staff_headers(client: AsyncClient, staff_user) -> dict:
    u, pwd = staff_user
    res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": pwd},
        headers={"X-Device-Id": "device-staff-1", "X-Platform": "android"},
    )
    assert res.status_code == 200, res.text
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}", "X-Device-Id": "device-staff-1"}


@pytest_asyncio.fixture
async def auth_headers(client: AsyncClient, demo_user) -> dict:
    u, pwd = demo_user
    res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": pwd},
        headers={"X-Device-Id": "device-test-1", "X-Platform": "android"},
    )
    assert res.status_code == 200, res.text
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}", "X-Device-Id": "device-test-1"}


@pytest_asyncio.fixture
async def admin_headers(client: AsyncClient, admin_user) -> dict:
    u, pwd = admin_user
    res = await client.post(
        "/auth/login",
        json={"phone": u.phone, "password": pwd},
        headers={"X-Device-Id": "device-admin-1", "X-Platform": "android"},
    )
    assert res.status_code == 200, res.text
    token = res.json()["access_token"]
    return {"Authorization": f"Bearer {token}", "X-Device-Id": "device-admin-1"}
