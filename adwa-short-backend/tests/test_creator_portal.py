from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.main import app
from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.rating import Rating
from app.models.revenue import Creator, Payout, RevenueSplitRule, RevenueTransaction
from app.models.review import Review
from app.models.user import User
from app.models.wallet import Wallet
from app.security import create_access_token, hash_password


@pytest.mark.asyncio
async def test_creator_authentication_and_password_recovery(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Create creator user & bound creator profile
        c_user = User(
            phone="+251933333333",
            email="portal_creator@adwashort.com",
            password_hash=hash_password("initial_pass123"),
            display_name="Portal Creator",
            role="creator",
            is_active=True,
        )
        db_session.add(c_user)
        await db_session.flush()

        creator = Creator(
            name="Portal Creator",
            email="portal_creator@adwashort.com",
            phone="+251933333333",
            display_name="Portal Creator",
            user_id=c_user.id,
            default_revenue_split_pct=50.0,
            is_active=True,
        )
        db_session.add(creator)
        await db_session.commit()

        # 1. Login with email
        login_res = await ac.post(
            "/auth/login",
            headers={"X-Device-Id": "device-creator-1"},
            json={"identifier": "portal_creator@adwashort.com", "password": "initial_pass123"},
        )
        assert login_res.status_code == 200, login_res.text
        data = login_res.json()
        assert data["role"] == "creator"
        assert data["creator_id"] == creator.id
        assert "access_token" in data

        # 2. Forgot password request
        forgot_res = await ac.post(
            "/auth/forgot-password",
            json={"email": "portal_creator@adwashort.com"},
        )
        assert forgot_res.status_code == 200
        forgot_data = forgot_res.json()
        assert forgot_data["status"] == "ok"
        reset_token = forgot_data["reset_token"]
        assert reset_token is not None

        # 3. Reset password request
        reset_res = await ac.post(
            "/auth/reset-password",
            json={"token": reset_token, "new_password": "new_secret_password_456"},
        )
        assert reset_res.status_code == 200
        assert reset_res.json()["status"] == "ok"

        # 4. Old password fails
        bad_login = await ac.post(
            "/auth/login",
            headers={"X-Device-Id": "device-creator-1"},
            json={"identifier": "portal_creator@adwashort.com", "password": "initial_pass123"},
        )
        assert bad_login.status_code == 401

        # 5. New password succeeds
        new_login = await ac.post(
            "/auth/login",
            headers={"X-Device-Id": "device-creator-1"},
            json={"identifier": "portal_creator@adwashort.com", "password": "new_secret_password_456"},
        )
        assert new_login.status_code == 200
        assert new_login.json()["creator_id"] == creator.id


@pytest.mark.asyncio
async def test_creator_portal_strict_rbac(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # 1. Regular viewer user
        viewer = User(
            phone="+251944444444",
            email="viewer@adwashort.com",
            password_hash=hash_password("viewer123"),
            display_name="Viewer",
            role="user",
            is_active=True,
        )
        db_session.add(viewer)

        # 2. Creator user
        creator_user = User(
            phone="+251955555555",
            email="creator_rbac@adwashort.com",
            password_hash=hash_password("creator123"),
            display_name="Creator RBAC",
            role="creator",
            is_active=True,
        )
        db_session.add(creator_user)
        await db_session.flush()

        creator = Creator(
            name="Creator RBAC",
            email="creator_rbac@adwashort.com",
            user_id=creator_user.id,
            default_revenue_split_pct=60.0,
            is_active=True,
        )
        db_session.add(creator)
        await db_session.commit()

        viewer_token = create_access_token(str(viewer.id), extra={"role": "user"})
        creator_token = create_access_token(str(creator_user.id), extra={"role": "creator"})

        # Viewer attempting to access creator portal -> 403 Forbidden
        v_dash = await ac.get("/creator/dashboard", headers={"Authorization": f"Bearer {viewer_token}"})
        assert v_dash.status_code == 403

        # Creator accessing creator portal -> 200 OK
        c_dash = await ac.get("/creator/dashboard", headers={"Authorization": f"Bearer {creator_token}"})
        assert c_dash.status_code == 200
        assert c_dash.json()["creator"]["id"] == creator.id

        # Creator attempting to access platform-wide admin endpoints -> 403 Forbidden
        c_staff = await ac.get("/admin/staff", headers={"Authorization": f"Bearer {creator_token}"})
        assert c_staff.status_code == 403

        c_users = await ac.get("/admin/users", headers={"Authorization": f"Bearer {creator_token}"})
        assert c_users.status_code == 403

        c_admin_creators = await ac.get("/creators", headers={"Authorization": f"Bearer {creator_token}"})
        assert c_admin_creators.status_code == 403


@pytest.mark.asyncio
async def test_creator_dashboard_and_content_breakdown(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Create creator
        c_user = User(
            phone="+251966666666",
            email="breakdown_creator@adwashort.com",
            password_hash=hash_password("test1234"),
            display_name="Breakdown Creator",
            role="creator",
            is_active=True,
        )
        db_session.add(c_user)
        await db_session.flush()

        creator = Creator(
            name="Breakdown Creator",
            email="breakdown_creator@adwashort.com",
            user_id=c_user.id,
            default_revenue_split_pct=70.0,
            is_active=True,
        )
        db_session.add(creator)
        await db_session.flush()

        # Create series & episodes bound to creator
        series = Series(
            title="Creator Drama",
            creator_id=creator.id,
            type="series",
            is_published=True,
        )
        db_session.add(series)
        await db_session.flush()

        ep1 = Episode(
            series_id=series.id,
            creator_id=creator.id,
            episode_number=1,
            title="Episode One",
            duration_seconds=300,
        )
        ep2 = Episode(
            series_id=series.id,
            creator_id=creator.id,
            episode_number=2,
            title="Episode Two",
            duration_seconds=300,
        )
        db_session.add_all([ep1, ep2])
        await db_session.flush()

        # 1. Add views:
        # ep1 has a view with 75 seconds (qualified >= 60s)
        # ep1 has a view with 30 seconds (unqualified < 60s)
        v1 = ViewLog(episode_id=ep1.id, series_id=series.id, watch_time_seconds=75)
        v2 = ViewLog(episode_id=ep1.id, series_id=series.id, watch_time_seconds=30)
        # ep2 has a qualified view with 120 seconds
        v3 = ViewLog(episode_id=ep2.id, series_id=series.id, watch_time_seconds=120)
        db_session.add_all([v1, v2, v3])

        # 2. Add revenue transactions:
        tx1 = RevenueTransaction(
            creator_id=creator.id,
            series_id=series.id,
            episode_id=ep1.id,
            source_type="coin_payment",
            gross_amount_birr=100.0,
            creator_share_birr=70.0,
            platform_share_birr=30.0,
        )
        tx2 = RevenueTransaction(
            creator_id=creator.id,
            series_id=series.id,
            episode_id=ep2.id,
            source_type="pass_consumption",
            gross_amount_birr=50.0,
            creator_share_birr=35.0,
            platform_share_birr=15.0,
        )
        db_session.add_all([tx1, tx2])

        # 3. Add payout
        payout = Payout(
            creator_id=creator.id,
            amount_birr=30.0,
            status="processed",
        )
        db_session.add(payout)

        # 4. Add rating and review
        viewer = User(
            phone="+251977777777",
            password_hash=hash_password("pass"),
            display_name="Fan Viewer",
            role="user",
            is_active=True,
        )
        db_session.add(viewer)
        await db_session.flush()

        rating = Rating(user_id=viewer.id, episode_id=ep1.id, series_id=series.id, rating=5)
        review = Review(user_id=viewer.id, episode_id=ep1.id, series_id=series.id, text="Incredible performance!")
        db_session.add_all([rating, review])
        await db_session.commit()

        creator_token = create_access_token(str(c_user.id), extra={"role": "creator"})
        headers = {"Authorization": f"Bearer {creator_token}"}

        # 1. Test Dashboard
        dash_res = await ac.get("/creator/dashboard", headers=headers)
        assert dash_res.status_code == 200
        dash_data = dash_res.json()
        assert dash_data["earnings"]["gross_revenue_birr"] == 150.0
        assert dash_data["earnings"]["creator_net_birr"] == 105.0
        assert dash_data["earnings"]["platform_commission_birr"] == 45.0
        assert dash_data["earnings"]["paid_out_birr"] == 30.0
        # Pending balance: 105 - 30 = 75
        assert dash_data["pending_balance_birr"] == 75.0
        # Qualified views: exactly 2 views meet >= 60s rule
        assert dash_data["metrics"]["qualified_views"] == 2
        assert dash_data["metrics"]["watch_time_seconds"] == 195  # 75 + 120 (30 is excluded!)
        assert dash_data["metrics"]["series_count"] == 1
        assert dash_data["metrics"]["episodes_count"] == 2

        # 2. Test Content Breakdown
        content_res = await ac.get("/creator/content?filter_type=all", headers=headers)
        assert content_res.status_code == 200
        items = content_res.json()
        assert len(items) == 3  # 1 series + 2 episodes

        # Series item
        s_item = next(it for it in items if it["is_series"])
        assert s_item["title"] == "Creator Drama"
        assert s_item["total_views"] == 2
        assert s_item["total_revenue_birr"] == 105.0
        assert s_item["revenue_ad_birr"] == 0.0

        # Episode 1 item
        ep1_item = next(it for it in items if it["episode_id"] == ep1.id)
        assert ep1_item["coin_views"] == 1
        assert ep1_item["revenue_coins_birr"] == 70.0
        assert ep1_item["average_rating"] == 5.0
        assert ep1_item["rating_count"] == 1

        # 3. Test Reviews
        reviews_res = await ac.get("/creator/reviews", headers=headers)
        assert reviews_res.status_code == 200
        rev_data = reviews_res.json()
        assert rev_data["total_reviews"] == 1
        assert rev_data["average_rating"] == 5.0
        assert rev_data["items"][0]["text"] == "Incredible performance!"
        assert rev_data["items"][0]["rating"] == 5
        assert rev_data["items"][0]["user_display_name"] == "Fan Viewer"

        # 4. Test Payout Account Settings
        payout_acc_get = await ac.get("/creator/payout-account", headers=headers)
        assert payout_acc_get.status_code == 200

        payout_acc_put = await ac.put(
            "/creator/payout-account",
            headers=headers,
            json={
                "bank_name": "Commercial Bank of Ethiopia",
                "bank_account_name": "Breakdown Creator Ent",
                "bank_account_number": "100012345678",
                "payment_method": "telebirr",
                "mobile_money_number": "+251911223344",
                "tax_id": "TIN-987654321",
            },
        )
        assert payout_acc_put.status_code == 200
        updated_acc = payout_acc_put.json()
        assert updated_acc["bank_name"] == "Commercial Bank of Ethiopia"
        assert updated_acc["mobile_money_number"] == "+251911223344"
        assert updated_acc["tax_id"] == "TIN-987654321"

        # 5. Test Transactions Ledger
        tx_res = await ac.get("/creator/transactions", headers=headers)
        assert tx_res.status_code == 200
        txs = tx_res.json()
        assert len(txs) == 2
        assert txs[0]["gross_amount_birr"] in (100.0, 50.0)

        # 6. Test Profile & Contract
        prof_res = await ac.get("/creator/profile", headers=headers)
        assert prof_res.status_code == 200
        prof = prof_res.json()
        assert prof["default_revenue_split_pct"] == 70.0  # Read only!

        update_prof = await ac.put(
            "/creator/profile",
            headers=headers,
            json={
                "display_name": "Renamed Creator",
                "bio": "Award-winning short film producer in Addis Ababa.",
                "avatar_url": "https://example.com/avatar.jpg",
                "phone": "+251988888888",
            },
        )
        assert update_prof.status_code == 200
        new_prof = update_prof.json()
        assert new_prof["display_name"] == "Renamed Creator"
        assert new_prof["bio"] == "Award-winning short film producer in Addis Ababa."
        assert new_prof["default_revenue_split_pct"] == 70.0  # Remains 70% as configured by admin
