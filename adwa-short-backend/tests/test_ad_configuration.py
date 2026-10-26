from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.main import app
from app.models.ad_unlock import AdImpressionLog, AdUnlockLog, AdUnlockRule
from app.models.content import Episode, Series
from app.models.revenue import Creator, RevenueTransaction
from app.models.user import User
from app.security import create_access_token, hash_password


@pytest.mark.asyncio
async def test_get_and_update_ad_configuration(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        admin = User(
            phone="+251900000001",
            email="superadmin@test.com",
            password_hash=hash_password("admin123"),
            display_name="Super Admin",
            role="super_admin",
            is_active=True,
        )
        viewer = User(
            phone="+251911111112",
            password_hash=hash_password("user123"),
            display_name="Viewer",
            role="user",
            is_active=True,
        )
        db_session.add_all([admin, viewer])
        await db_session.commit()

        admin_token = create_access_token(str(admin.id), extra={"role": "super_admin"})
        viewer_token = create_access_token(str(viewer.id), extra={"role": "user"})

        # 1. Get default rule
        get_res = await ac.get("/ad-unlocks/rule")
        assert get_res.status_code == 200
        data = get_res.json()
        assert data["ads_required"] >= 1
        assert "rewarded_unit_id" in data
        assert "reward_ad_value_birr" in data

        # 2. Viewer cannot update (403)
        bad_put = await ac.put(
            "/ad-unlocks/rule",
            headers={"Authorization": f"Bearer {viewer_token}"},
            json={"ads_required": 3},
        )
        assert bad_put.status_code == 403

        # 3. Admin updates configuration
        put_res = await ac.put(
            "/ad-unlocks/rule",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "provider": "unity",
                "app_id": "unity-game-id-12345",
                "rewarded_unit_id": "rewardedVideo_adwa",
                "interstitial_unit_id": "interstitial_adwa",
                "banner_unit_id": "banner_adwa",
                "api_key": "unity-api-key-xyz",
                "callback_secret": "my-secure-s2s-secret-999",
                "ads_required": 1,
                "episodes_unlocked": 1,
                "reward_ad_value_birr": 0.75,
                "estimated_cpm_birr": 60.0,
                "test_mode": False,
            },
        )
        assert put_res.status_code == 200
        updated = put_res.json()
        assert updated["provider"] == "unity"
        assert updated["app_id"] == "unity-game-id-12345"
        assert updated["reward_ad_value_birr"] == 0.75
        assert updated["ads_required"] == 1
        assert updated["test_mode"] is False


@pytest.mark.asyncio
async def test_watched_ad_monetization_100pct_platform_0pct_creator(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Create creator
        c_user = User(
            phone="+251922222221",
            email="ad_creator@adwashort.com",
            password_hash=hash_password("creator123"),
            display_name="Ad Creator",
            role="creator",
            is_active=True,
        )
        db_session.add(c_user)
        await db_session.flush()

        creator = Creator(
            name="Ad Creator",
            email="ad_creator@adwashort.com",
            user_id=c_user.id,
            default_revenue_split_pct=60.0,
            is_active=True,
        )
        db_session.add(creator)
        await db_session.flush()

        # Create series & episode explicitly bound to creator
        series = Series(title="Free Ad Series", creator_id=creator.id, is_published=True)
        db_session.add(series)
        await db_session.flush()

        episode = Episode(
            series_id=series.id,
            creator_id=creator.id,
            episode_number=1,
            title="Ad Unlocked Ep 1",
            duration_seconds=120,
        )
        db_session.add(episode)

        # Viewer user
        viewer = User(
            phone="+251933333332",
            password_hash=hash_password("pass"),
            display_name="Ad Watcher",
            role="user",
            is_active=True,
        )
        db_session.add(viewer)
        await db_session.commit()

        viewer_token = create_access_token(str(viewer.id), extra={"role": "user"})
        headers = {"Authorization": f"Bearer {viewer_token}"}

        # Watch ad to unlock
        res = await ac.post(
            "/ad-unlocks/watched",
            headers=headers,
            json={"episode_id": episode.id, "ads_watched": 2, "ad_network": "admob"},
        )
        assert res.status_code == 201, res.text
        unlock_log = res.json()
        assert unlock_log["episode_id"] == episode.id
        assert unlock_log["user_id"] == viewer.id
        assert unlock_log["revenue_birr"] > 0

        # Verify RevenueTransaction in database:
        # 100% of the ad revenue belongs to ADWA SHORT platform, creators earn 0%
        tx_res = await db_session.execute(
            select(RevenueTransaction).where(
                RevenueTransaction.source_type == "ad_revenue",
                RevenueTransaction.episode_id == episode.id,
                RevenueTransaction.user_id == viewer.id,
            )
        )
        tx = tx_res.scalar_one_or_none()
        assert tx is not None
        assert float(tx.creator_share_birr) == 0.0, "Creators must earn 0% from ad viewing"
        assert float(tx.platform_share_birr) == float(tx.gross_amount_birr), "Platform must retain 100% of ad revenue"
        assert tx.creator_id is None, "Ad revenue transaction must not credit creator"

        # Check creator dashboard to confirm net earnings are still 0
        creator_token = create_access_token(str(c_user.id), extra={"role": "creator"})
        c_dash = await ac.get("/creator/dashboard", headers={"Authorization": f"Bearer {creator_token}"})
        assert c_dash.status_code == 200
        assert c_dash.json()["earnings"]["creator_net_birr"] == 0.0


@pytest.mark.asyncio
async def test_strict_ad_unlock_completion_verification(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        series = Series(title="Strict Verification Series", is_published=True)
        db_session.add(series)
        await db_session.flush()

        episode = Episode(
            series_id=series.id,
            episode_number=5,
            title="Locked Episode 5",
            duration_seconds=90,
        )
        db_session.add(episode)

        viewer = User(
            phone="+251944444444",
            password_hash=hash_password("pass"),
            display_name="Strict Watcher",
            role="user",
            is_active=True,
        )
        db_session.add(viewer)
        await db_session.commit()

        viewer_token = create_access_token(str(viewer.id), extra={"role": "user"})
        headers = {"Authorization": f"Bearer {viewer_token}"}

        # 1. Set rule: ads_required = 3
        rule_res = await db_session.execute(select(AdUnlockRule).limit(1))
        rule = rule_res.scalar_one_or_none()
        if rule is None:
            rule = AdUnlockRule(ads_required=3, is_active=True)
            db_session.add(rule)
        else:
            rule.ads_required = 3
            rule.is_active = True
        await db_session.commit()

        # Attempt incomplete batch (1 ad instead of 3) -> 422
        res_incomplete = await ac.post(
            "/ad-unlocks/watched",
            headers=headers,
            json={"episode_id": episode.id, "ads_watched": 1, "ad_network": "admob"},
        )
        assert res_incomplete.status_code == 422
        assert "Need to watch 3 ads" in res_incomplete.text

        # Attempt 0 ads -> 422
        res_zero = await ac.post(
            "/ad-unlocks/watched",
            headers=headers,
            json={"episode_id": episode.id, "ads_watched": 0, "ad_network": "admob"},
        )
        assert res_zero.status_code == 422

        # Complete full batch of 3 ads -> 201
        res_success = await ac.post(
            "/ad-unlocks/watched",
            headers=headers,
            json={"episode_id": episode.id, "ads_watched": 3, "ad_network": "admob"},
        )
        assert res_success.status_code == 201

        # Attempt to unlock again -> 409 Conflict (Already unlocked)
        res_duplicate = await ac.post(
            "/ad-unlocks/watched",
            headers=headers,
            json={"episode_id": episode.id, "ads_watched": 3, "ad_network": "admob"},
        )
        assert res_duplicate.status_code == 409
        assert "already unlocked" in res_duplicate.text.lower()

        # Disable ads -> 403 Forbidden on new episode
        episode2 = Episode(series_id=series.id, episode_number=6, title="Locked Episode 6")
        db_session.add(episode2)
        rule.is_active = False
        await db_session.commit()

        res_disabled = await ac.post(
            "/ad-unlocks/watched",
            headers=headers,
            json={"episode_id": episode2.id, "ads_watched": 3, "ad_network": "admob"},
        )
        assert res_disabled.status_code == 403
        assert "disabled" in res_disabled.text.lower()


@pytest.mark.asyncio
async def test_s2s_reward_callback_webhook(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Configure rule with known secret
        rule_res = await db_session.execute(select(AdUnlockRule).limit(1))
        rule = rule_res.scalar_one_or_none()
        if rule is None:
            rule = AdUnlockRule(
                ads_required=1,
                episodes_unlocked=1,
                is_active=True,
                callback_secret="test_secret_123",
                reward_ad_value_birr=0.60,
            )
            db_session.add(rule)
        else:
            rule.callback_secret = "test_secret_123"
            rule.reward_ad_value_birr = 0.60
            rule.ads_required = 1

        # Create user & episode
        user = User(
            phone="+251944444443",
            password_hash=hash_password("pass"),
            display_name="Webhook User",
            role="user",
            is_active=True,
        )
        db_session.add(user)
        await db_session.flush()

        series = Series(title="Webhook Series", is_published=True)
        db_session.add(series)
        await db_session.flush()

        ep = Episode(
            series_id=series.id,
            episode_number=1,
            title="Webhook Ep",
            duration_seconds=120,
        )
        db_session.add(ep)
        await db_session.commit()

        # 1. Invalid secret returns 403
        bad_cb = await ac.post(
            "/ad-unlocks/reward-callback",
            json={
                "user_id": user.id,
                "episode_id": ep.id,
                "secret": "wrong_secret",
            },
        )
        assert bad_cb.status_code == 403

        # 2. Valid secret unlocks episode
        good_cb = await ac.post(
            "/ad-unlocks/reward-callback",
            json={
                "user_id": user.id,
                "episode_id": ep.id,
                "secret": "test_secret_123",
            },
        )
        assert good_cb.status_code == 200
        data = good_cb.json()
        assert data["status"] == "success"
        assert data["revenue_credited_to_platform_birr"] == 0.60

        # Verify revenue transaction (100% platform, 0% creator)
        tx_res = await db_session.execute(
            select(RevenueTransaction).where(
                RevenueTransaction.source_type == "ad_revenue",
                RevenueTransaction.episode_id == ep.id,
                RevenueTransaction.user_id == user.id,
            )
        )
        tx = tx_res.scalar_one_or_none()
        assert tx is not None
        assert float(tx.creator_share_birr) == 0.0
        assert float(tx.platform_share_birr) == 0.60

        # 3. Duplicate callback returns already unlocked
        dup_cb = await ac.post(
            "/ad-unlocks/reward-callback",
            json={
                "user_id": user.id,
                "episode_id": ep.id,
                "secret": "test_secret_123",
            },
        )
        assert dup_cb.status_code == 200
        assert dup_cb.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_ad_impression_and_admin_logs(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        admin = User(
            phone="+251955555554",
            password_hash=hash_password("admin"),
            display_name="Log Admin",
            role="super_admin",
            is_active=True,
        )
        user = User(
            phone="+251966666665",
            password_hash=hash_password("pass"),
            display_name="Impression User",
            role="user",
            is_active=True,
        )
        db_session.add_all([admin, user])
        await db_session.flush()

        series = Series(title="Imp Series", is_published=True)
        db_session.add(series)
        await db_session.flush()

        ep = Episode(series_id=series.id, episode_number=1, title="Imp Ep")
        db_session.add(ep)
        await db_session.commit()

        user_token = create_access_token(str(user.id), extra={"role": "user"})
        admin_token = create_access_token(str(admin.id), extra={"role": "super_admin"})

        # Log an impression
        imp_res = await ac.post(
            "/ad-unlocks/impression",
            headers={"Authorization": f"Bearer {user_token}"},
            json={
                "episode_id": ep.id,
                "ad_unit_id": "ca-app-pub-test-rewarded",
                "ad_network": "admob",
                "ad_type": "rewarded",
                "revenue_birr": 0.08,
            },
        )
        assert imp_res.status_code == 201
        assert imp_res.json()["revenue_birr"] == 0.08

        # Admin fetches logs
        log_res = await ac.get(
            "/ad-unlocks/logs",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert log_res.status_code == 200
        assert isinstance(log_res.json(), list)


@pytest.mark.asyncio
async def test_api_v1_ads_dynamic_payout_and_static_fallback(db_session):
    """
    Validates S2S webhook endpoint (/api/v1/ads/callback & /api/v1/ads/postback):
    1. Dynamic Revenue Logging: When exact payout is sent, records exact amount (100% platform, 0% creator).
    2. Static Fallbacks: When no payout is sent, falls back to AD_REWARD_VALUE_BIRR (0.25 ETB).
    3. Security: Secure secret verification via headers and params.
    """
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # 1. Setup creator, series, episodes, viewer
        c_user = User(
            phone="+251977777776",
            email="s2s_creator@adwashort.com",
            password_hash=hash_password("pass"),
            display_name="S2S Creator",
            role="creator",
            is_active=True,
        )
        db_session.add(c_user)
        await db_session.flush()

        creator = Creator(
            name="S2S Creator",
            email="s2s_creator@adwashort.com",
            user_id=c_user.id,
            default_revenue_split_pct=70.0,
            is_active=True,
        )
        db_session.add(creator)
        await db_session.flush()

        series = Series(title="S2S Series", creator_id=creator.id, is_published=True)
        db_session.add(series)
        await db_session.flush()

        ep1 = Episode(series_id=series.id, creator_id=creator.id, episode_number=1, title="Dynamic Payout Ep")
        ep2 = Episode(series_id=series.id, creator_id=creator.id, episode_number=2, title="Static Fallback Ep")
        viewer = User(
            phone="+251988888887",
            password_hash=hash_password("pass"),
            display_name="S2S Viewer",
            role="user",
            is_active=True,
        )
        db_session.add_all([ep1, ep2, viewer])
        await db_session.commit()

        # Configure rule with known secret and default static fallback
        rule_res = await db_session.execute(select(AdUnlockRule).limit(1))
        rule = rule_res.scalar_one_or_none()
        if rule is None:
            rule = AdUnlockRule(
                ads_required=1,
                episodes_unlocked=1,
                is_active=True,
                callback_secret="secret_s2s_test_token",
                reward_ad_value_birr=0.25,
                estimated_cpm_birr=250.0,
            )
            db_session.add(rule)
        else:
            rule.callback_secret = "secret_s2s_test_token"
            rule.reward_ad_value_birr = 0.25
            rule.estimated_cpm_birr = 250.0
            rule.ads_required = 1
        await db_session.commit()

        # ======================================================================
        # Test Case 1: Dynamic Revenue Logging via /api/v1/ads/callback
        # Exact payout value passed (e.g. 0.85 Birr)
        # ======================================================================
        dyn_res = await ac.post(
            "/api/v1/ads/callback",
            headers={"X-Ad-Secret": "secret_s2s_test_token"},
            json={
                "user_id": viewer.id,
                "episode_id": ep1.id,
                "ad_network": "admob",
                "transaction_id": "admob_tx_dyn_1001",
                "payout_birr": 0.85,
            },
        )
        assert dyn_res.status_code == 200, dyn_res.text
        dyn_data = dyn_res.json()
        assert dyn_data["status"] == "success"
        assert dyn_data["revenue_birr"] == 0.85
        assert dyn_data["revenue_source"] == "dynamic_payout"
        assert dyn_data["platform_share_birr"] == 0.85
        assert dyn_data["creator_share_birr"] == 0.0

        # Check AdUnlockLog record
        log1 = (await db_session.execute(
            select(AdUnlockLog).where(AdUnlockLog.user_id == viewer.id, AdUnlockLog.episode_id == ep1.id)
        )).scalar_one_or_none()
        assert log1 is not None
        assert float(log1.revenue_birr) == 0.85
        assert log1.verified_via == "s2s_webhook"

        # Check RevenueTransaction: 100% platform, 0% creator
        tx1 = (await db_session.execute(
            select(RevenueTransaction).where(
                RevenueTransaction.source_type == "ad_revenue",
                RevenueTransaction.episode_id == ep1.id,
                RevenueTransaction.user_id == viewer.id,
            )
        )).scalar_one_or_none()
        assert tx1 is not None
        assert float(tx1.gross_amount_birr) == 0.85
        assert float(tx1.platform_share_birr) == 0.85
        assert float(tx1.creator_share_birr) == 0.0
        assert tx1.creator_id is None

        # ======================================================================
        # Test Case 2: Static Fallback via /api/v1/ads/postback
        # No live payout data supplied; should fall back to AD_REWARD_VALUE_BIRR (0.25)
        # ======================================================================
        static_res = await ac.post(
            "/api/v1/ads/postback",
            json={
                "user_id": viewer.id,
                "episode_id": ep2.id,
                "secret": "secret_s2s_test_token",
                "ad_network": "unity",
                "transaction_id": "unity_tx_fallback_2002",
            },
        )
        assert static_res.status_code == 200, static_res.text
        static_data = static_res.json()
        assert static_data["status"] == "success"
        assert static_data["revenue_birr"] == 0.25
        assert static_data["revenue_source"] == "static_fallback"
        assert static_data["platform_share_birr"] == 0.25
        assert static_data["creator_share_birr"] == 0.0

        # Check RevenueTransaction: 100% platform, 0% creator
        tx2 = (await db_session.execute(
            select(RevenueTransaction).where(
                RevenueTransaction.source_type == "ad_revenue",
                RevenueTransaction.episode_id == ep2.id,
                RevenueTransaction.user_id == viewer.id,
            )
        )).scalar_one_or_none()
        assert tx2 is not None
        assert float(tx2.gross_amount_birr) == 0.25
        assert float(tx2.platform_share_birr) == 0.25
        assert float(tx2.creator_share_birr) == 0.0
        assert tx2.creator_id is None

        # ======================================================================
        # Test Case 3: GET Callback with query parameters
        # ======================================================================
        get_res = await ac.get(
            f"/api/v1/ads/callback?user_id={viewer.id}&episode_id={ep1.id}&secret=secret_s2s_test_token"
        )
        assert get_res.status_code == 200
        assert get_res.json()["status"] == "ok"  # already unlocked idempotency

        # ======================================================================
        # Test Case 4: Invalid secret rejected with 403 Forbidden
        # ======================================================================
        bad_sec_res = await ac.post(
            "/api/v1/ads/callback",
            json={
                "user_id": viewer.id,
                "episode_id": ep1.id,
                "secret": "unauthorized_secret",
            },
        )
        assert bad_sec_res.status_code == 403

