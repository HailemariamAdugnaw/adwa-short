from __future__ import annotations

from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.content import Episode, Series
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.wallet import Wallet
from app.utils.time import utcnow


@pytest.mark.asyncio
async def test_active_pass_and_subscription_endpoint_empty(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user

    res_p = await client.get("/passes/active", headers=auth_headers)
    assert res_p.status_code == 200, res_p.text
    data_p = res_p.json()
    assert data_p["has_active_pass"] is False
    assert "server_time" in data_p

    res_s = await client.get("/subscriptions/active", headers=auth_headers)
    assert res_s.status_code == 200, res_s.text
    data_s = res_s.json()
    assert data_s["has_active_subscription"] is False
    assert "server_time" in data_s

    res_dash = await client.get("/subscriptions/user-access", headers=auth_headers)
    assert res_dash.status_code == 200, res_dash.text
    data_dash = res_dash.json()
    assert data_dash["active_pass"]["has_active_pass"] is False
    assert data_dash["active_subscription"]["has_active_subscription"] is False
    assert "server_time" in data_dash


@pytest.mark.asyncio
async def test_active_pass_lifecycle_and_stacking(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    now = utcnow()

    async with AsyncSessionLocal() as s:
        # Create pass
        tpass = TimePass(name="24-Hour Binge Pass", duration_hours=24, price_birr=30.0, is_active=True)
        s.add(tpass)
        await s.flush()

        # Update user wallet balance
        wres = await s.execute(select(Wallet).where(Wallet.user_id == user.id))
        w = wres.scalar_one_or_none()
        if w is None:
            w = Wallet(user_id=user.id, balance_birr=200.0, balance_coins=100)
            s.add(w)
        else:
            w.balance_birr = 200.0
            w.balance_coins = 100

        # Seed initial active pass (expires in 24 hours)
        purchase = TimePassPurchase(
            user_id=user.id,
            pass_id=tpass.id,
            starts_at=now,
            expires_at=now + timedelta(hours=24),
            is_active=True,
        )
        s.add(purchase)
        await s.commit()
        pass_id = tpass.id

    # Check active pass endpoint
    res_p = await client.get("/passes/active", headers=auth_headers)
    assert res_p.status_code == 200
    data_p = res_p.json()
    assert data_p["has_active_pass"] is True
    assert data_p["name"] == "24-Hour Binge Pass"
    assert data_p["duration_hours"] == 24
    assert 86000 < data_p["remaining_seconds"] <= 86400

    # Repurchase pass via /passes/purchase -> must succeed and STACK duration!
    repurchase_res = await client.post(
        "/passes/purchase",
        json={"pass_id": pass_id},
        headers=auth_headers,
    )
    assert repurchase_res.status_code == 201, repurchase_res.text
    repurchase_data = repurchase_res.json()
    assert repurchase_data["is_active"] is True

    # Active pass endpoint must now reflect stacked duration (~48 hours, > 170000 seconds)
    stacked_res = await client.get("/passes/active", headers=auth_headers)
    assert stacked_res.status_code == 200
    stacked_data = stacked_res.json()
    assert stacked_data["has_active_pass"] is True
    assert stacked_data["remaining_seconds"] > 170000

    # CBE payment initiate for time_pass must also succeed (no duplicate block)
    cbe_init = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "time_pass", "item_id": pass_id},
        headers=auth_headers,
    )
    assert cbe_init.status_code == 201, cbe_init.text
    assert cbe_init.json()["item_type"] == "time_pass"


@pytest.mark.asyncio
async def test_active_subscription_lifecycle_and_unsubscribe(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    now = utcnow()

    async with AsyncSessionLocal() as s:
        # Create plan
        plan = SubscriptionPlan(name="VIP Monthly Pass", billing_cycle="monthly", price_birr=150.0, is_active=True)
        s.add(plan)
        await s.flush()

        sub = Subscription(
            user_id=user.id,
            plan_id=plan.id,
            status="active",
            started_at=now,
            next_billing_at=now + timedelta(days=30),
        )
        s.add(sub)
        await s.commit()
        plan_id = plan.id

    # Check active subscription endpoint
    res_s = await client.get("/subscriptions/active", headers=auth_headers)
    assert res_s.status_code == 200
    data_s = res_s.json()
    assert data_s["has_active_subscription"] is True
    assert data_s["plan_name"] == "VIP Monthly Pass"
    assert data_s["billing_cycle"] == "monthly"
    assert data_s["remaining_seconds"] > 2500000

    # Attempt duplicate subscribe -> must reject with 400
    dup_sub = await client.post(
        "/subscriptions/subscribe",
        json={"plan_id": plan_id},
        headers=auth_headers,
    )
    assert dup_sub.status_code == 400
    assert "already have an active subscription" in dup_sub.json()["detail"]

    # Attempt duplicate CBE initiate -> must reject with 400
    dup_cbe = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "subscription", "item_id": plan_id},
        headers=auth_headers,
    )
    assert dup_cbe.status_code == 400
    assert "already have an active subscription" in dup_cbe.json()["detail"]

    # Cancel via POST /subscriptions/unsubscribe
    unsub_res = await client.post("/subscriptions/unsubscribe", headers=auth_headers)
    assert unsub_res.status_code == 200
    assert unsub_res.json()["status"] == "canceled"

    # Now verify active subscription is false
    res_after = await client.get("/subscriptions/active", headers=auth_headers)
    assert res_after.json()["has_active_subscription"] is False


@pytest.mark.asyncio
async def test_server_side_expiry_locks_content(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    past_time = utcnow() - timedelta(hours=2)

    async with AsyncSessionLocal() as s:
        # Create series and locked episode #5
        series = Series(title="Drama Series", free_episode_count=1, is_published=True)
        s.add(series)
        await s.flush()

        ep = Episode(series_id=series.id, episode_number=5, title="Episode 5", is_published=True)
        s.add(ep)
        await s.flush()

        # Seed an EXPIRED pass (expires_at in the past, but is_active was True)
        tpass = TimePass(name="Old Pass", duration_hours=1, price_birr=10.0, is_active=True)
        s.add(tpass)
        await s.flush()

        expired_purchase = TimePassPurchase(
            user_id=user.id,
            pass_id=tpass.id,
            starts_at=past_time - timedelta(hours=1),
            expires_at=past_time,
            is_active=True,
        )
        s.add(expired_purchase)
        await s.commit()
        ep_id = ep.id

    # When accessing episode, backend server UTC check must deny access
    access_res = await client.get(f"/episodes/{ep_id}/access", headers=auth_headers)
    assert access_res.status_code == 200
    data = access_res.json()
    assert data["access"] == "denied"
    assert "server_time" in data
