from __future__ import annotations

import pytest
from sqlalchemy import select

from app.models.content import Episode, Series
from app.models.wallet import Wallet, WalletTransaction
from app.models.settings import AppSettings
from app.services.monetization import AccessResult, get_effective_free_episodes, resolve_access

pytestmark = pytest.mark.asyncio


async def _seed_test_series(client, admin_headers, title: str, free_count: int | None = None):
    cat = await client.post("/categories", json={"name": f"Cat_{title}"}, headers=admin_headers)
    cat_id = cat.json()["id"]

    series_payload = {
        "title": title,
        "category_id": cat_id,
        "type": "series",
        "is_published": True,
        "total_episodes": 4,
    }
    if free_count is not None:
        series_payload["free_episode_count"] = free_count

    s_res = await client.post("/series", json=series_payload, headers=admin_headers)
    assert s_res.status_code == 201, s_res.text
    series_id = s_res.json()["id"]

    ep_ids = []
    for n in range(1, 5):
        ep_res = await client.post(
            "/episodes",
            json={
                "series_id": series_id,
                "episode_number": n,
                "title": f"{title} Ep {n}",
                "coin_cost": 15 if n == 4 else 0,
            },
            headers=admin_headers,
        )
        assert ep_res.status_code == 201
        ep_id = ep_res.json()["id"]
        # Publish
        await client.post(f"/admin/content/episodes/{ep_id}/publish", headers=admin_headers)
        ep_ids.append(ep_id)

    return series_id, ep_ids


async def test_hierarchical_free_episodes_global_default(client, admin_headers, db_session):
    # Set global default to 3 in app_settings
    res = await db_session.execute(select(AppSettings).where(AppSettings.key == "free_trial_default_episodes"))
    st = res.scalar_one_or_none()
    if st:
        st.value = "3"
    else:
        db_session.add(AppSettings(key="free_trial_default_episodes", value="3", description=""))
    await db_session.commit()

    # Create series with no series-level override (free_episode_count=None)
    series_id, ep_ids = await _seed_test_series(client, admin_headers, "GlobalDefaultSeries", free_count=None)

    # Fetch series details as public/viewer
    s_detail = await client.get(f"/series/{series_id}")
    assert s_detail.status_code == 200
    body = s_detail.json()
    assert body["effective_free_episodes"] == 3

    episodes = body["episodes"]
    assert len(episodes) == 4

    # Ep 1, 2, 3 must be free & unlocked by default
    assert episodes[0]["is_free"] is True
    assert episodes[0]["is_locked"] is False
    assert episodes[0]["is_accessible"] is True

    assert episodes[1]["is_free"] is True
    assert episodes[1]["is_locked"] is False
    assert episodes[1]["is_accessible"] is True

    assert episodes[2]["is_free"] is True
    assert episodes[2]["is_locked"] is False
    assert episodes[2]["is_accessible"] is True

    # Ep 4 must be locked
    assert episodes[3]["is_free"] is False
    assert episodes[3]["is_locked"] is True
    assert episodes[3]["is_accessible"] is False


async def test_hierarchical_free_episodes_series_override(client, admin_headers):
    # Create series explicitly overriding free episodes to 1
    series_id, ep_ids = await _seed_test_series(client, admin_headers, "SeriesOverride1", free_count=1)

    s_detail = await client.get(f"/series/{series_id}")
    assert s_detail.status_code == 200
    body = s_detail.json()
    assert body["effective_free_episodes"] == 1
    assert body["free_episode_count"] == 1

    episodes = body["episodes"]
    # Only Ep 1 is free
    assert episodes[0]["is_free"] is True
    assert episodes[0]["is_locked"] is False

    # Ep 2, 3, 4 are locked
    assert episodes[1]["is_free"] is False
    assert episodes[1]["is_locked"] is True

    assert episodes[2]["is_free"] is False
    assert episodes[2]["is_locked"] is True

    assert episodes[3]["is_free"] is False
    assert episodes[3]["is_locked"] is True


async def test_hierarchical_free_episodes_zero_override(client, admin_headers):
    # Create series explicitly overriding free episodes to 0 (all locked)
    series_id, ep_ids = await _seed_test_series(client, admin_headers, "SeriesOverrideZero", free_count=0)

    s_detail = await client.get(f"/series/{series_id}")
    assert s_detail.status_code == 200
    body = s_detail.json()
    assert body["effective_free_episodes"] == 0
    assert body["free_episode_count"] == 0

    episodes = body["episodes"]
    # Episode 1 is locked because free_episode_count is 0
    assert episodes[0]["is_free"] is False
    assert episodes[0]["is_locked"] is True


async def test_coin_unlock_deducts_balance_and_records_transaction(client, admin_headers, auth_headers, demo_user, db_session):
    user_obj = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    # Ensure demo user has 50 coins in wallet
    w_res = await db_session.execute(select(Wallet).where(Wallet.user_id == user_obj.id))
    wallet = w_res.scalar_one_or_none()
    assert wallet is not None
    wallet.balance_coins = 50
    await db_session.commit()

    # Create series with free_count=1
    series_id, ep_ids = await _seed_test_series(client, admin_headers, "CoinUnlockTest", free_count=1)
    locked_ep_id = ep_ids[3] # coin_cost is 15

    # Check access before unlocking -> denied need_coins
    access_chk = await client.get(f"/episodes/{locked_ep_id}/access", headers=auth_headers)
    assert access_chk.status_code == 200
    assert access_chk.json()["access"] == "denied"
    assert access_chk.json()["reason"] == "need_coins"

    # Unlock episode using coins
    unlock_res = await client.post(f"/episodes/{locked_ep_id}/unlock", headers=auth_headers)
    assert unlock_res.status_code == 200
    unlock_body = unlock_res.json()

    assert unlock_body["coins_deducted"] == 15
    assert unlock_body["new_balance_coins"] == 35
    assert unlock_body["is_accessible"] is True
    assert unlock_body["is_locked"] is False

    # Check wallet balance in database
    await db_session.refresh(wallet)
    assert wallet.balance_coins == 35

    # Check WalletTransaction in database
    tx_res = await db_session.execute(
        select(WalletTransaction).where(
            WalletTransaction.wallet_id == wallet.id,
            WalletTransaction.reference == f"episode:{locked_ep_id}",
        )
    )
    tx = tx_res.scalar_one_or_none()
    assert tx is not None
    assert tx.amount_coins == -15
    assert tx.type == "purchase"

    # Check access after unlocking -> allowed via coins
    access_after = await client.get(f"/episodes/{locked_ep_id}/access", headers=auth_headers)
    assert access_after.status_code == 200
    assert access_after.json()["access"] == "allowed"
    assert access_after.json()["method"] == "allowed_coins"


async def test_coin_unlock_insufficient_coins_returns_402(client, admin_headers, auth_headers, demo_user, db_session):
    user_obj = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    # Set demo user wallet balance to 5 coins
    w_res = await db_session.execute(select(Wallet).where(Wallet.user_id == user_obj.id))
    wallet = w_res.scalar_one_or_none()
    assert wallet is not None
    wallet.balance_coins = 5
    await db_session.commit()

    # Create series with free_count=1, ep 4 costs 15 coins
    series_id, ep_ids = await _seed_test_series(client, admin_headers, "CoinInsufficientTest", free_count=1)
    locked_ep_id = ep_ids[3] # 15 coins required

    unlock_res = await client.post(f"/episodes/{locked_ep_id}/unlock", headers=auth_headers)
    assert unlock_res.status_code == 402
    assert unlock_res.json()["detail"] == "need_coins"

    # Wallet balance should remain untouched at 5 coins
    await db_session.refresh(wallet)
    assert wallet.balance_coins == 5


async def test_dynamic_coin_pricing_series_override(client, admin_headers, auth_headers, demo_user, db_session):
    user_obj = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    # Reset wallet balance to 100 coins
    w_res = await db_session.execute(select(Wallet).where(Wallet.user_id == user_obj.id))
    wallet = w_res.scalar_one_or_none()
    assert wallet is not None
    wallet.balance_coins = 100
    await db_session.commit()

    # Verify public settings exposes default_episode_coin_cost
    pub = await client.get("/settings/public")
    assert pub.status_code == 200
    assert pub.json()["default_episode_coin_cost"] == 10

    # Create category & series with series-level coin_cost override = 20
    cat = await client.post("/categories", json={"name": "Cat_SeriesCoinOverride"}, headers=admin_headers)
    cat_id = cat.json()["id"]

    s_res = await client.post(
        "/series",
        json={
            "title": "SeriesCoinCost20",
            "category_id": cat_id,
            "type": "series",
            "is_published": True,
            "free_episode_count": 1,
            "coin_cost": 20,
        },
        headers=admin_headers,
    )
    assert s_res.status_code == 201
    s_data = s_res.json()
    assert s_data["coin_cost"] == 20
    assert s_data["effective_coin_cost"] == 20
    series_id = s_data["id"]

    # Create episode 2 with coin_cost=0 (should inherit series coin_cost=20)
    ep_res = await client.post(
        "/episodes",
        json={
            "series_id": series_id,
            "episode_number": 2,
            "title": "Ep 2 Inheriting Series Cost",
            "coin_cost": 0,
        },
        headers=admin_headers,
    )
    assert ep_res.status_code == 201
    ep_id = ep_res.json()["id"]
    await client.post(f"/admin/content/episodes/{ep_id}/publish", headers=admin_headers)

    # Check series details endpoint
    s_detail = await client.get(f"/series/{series_id}")
    assert s_detail.status_code == 200
    assert s_detail.json()["effective_coin_cost"] == 20
    ep_detail = s_detail.json()["episodes"][0]
    assert ep_detail["effective_coin_cost"] == 20

    # Unlock episode 2 with coins -> should deduct 20 coins
    unlock_res = await client.post(f"/episodes/{ep_id}/unlock", headers=auth_headers)
    assert unlock_res.status_code == 200
    body = unlock_res.json()
    assert body["coins_deducted"] == 20
    assert body["new_balance_coins"] == 80

