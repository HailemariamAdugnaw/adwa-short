from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.main import app
from app.models.loyalty import LoyaltyRewardConfig, LoyaltyRewardGrant
from app.models.user import User
from app.models.wallet import Wallet
from app.security import create_access_token, hash_password


@pytest.mark.asyncio
async def test_loyalty_config_and_status(db_session):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        admin = User(
            phone="+251911112233",
            password_hash=hash_password("admin"),
            display_name="Admin",
            role="super_admin",
            is_active=True,
        )
        user = User(
            phone="+251922223344",
            password_hash=hash_password("pass"),
            display_name="Viewer",
            role="user",
            is_active=True,
        )
        db_session.add_all([admin, user])
        await db_session.flush()

        wallet = Wallet(user_id=user.id, balance_birr=30.0, balance_coins=5)
        db_session.add(wallet)
        await db_session.commit()

        admin_token = create_access_token(str(admin.id), extra={"role": "super_admin"})
        user_token = create_access_token(str(user.id), extra={"role": "user"})

        # 1. Super Admin updates loyalty config
        put_res = await ac.put(
            "/loyalty/config",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={
                "min_balance_birr": 50.0,
                "max_balance_birr": 500.0,
                "daily_access_days": 7,
                "free_coins": 100,
                "free_full_series_count": 2,
                "is_active": True,
            },
        )
        assert put_res.status_code == 200
        assert put_res.json()["min_balance_birr"] == 50.0
        assert put_res.json()["free_coins"] == 100

        # 2. Regular user fetches loyalty status (balance = 30, min = 50 -> qualifies: False)
        status_res = await ac.get(
            "/loyalty/status",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert status_res.status_code == 200
        st = status_res.json()
        assert st["qualifies"] is False
        assert st["wallet_balance_birr"] == 30.0
        assert st["needed_birr"] == 20.0
        assert st["progress_pct"] == 60.0

        # 3. User tries to claim before qualifying -> 400
        bad_claim = await ac.post(
            "/loyalty/claim",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert bad_claim.status_code == 400

        # 4. Increase user balance to 60.0 Birr -> qualifies: True
        wallet.balance_birr = 60.0
        await db_session.commit()

        good_status = await ac.get(
            "/loyalty/status",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert good_status.status_code == 200
        assert good_status.json()["qualifies"] is True

        # 5. User claims loyalty reward
        claim_res = await ac.post(
            "/loyalty/claim",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert claim_res.status_code == 200
        claim_data = claim_res.json()
        assert claim_data["coins_awarded"] == 100
        assert claim_data["new_balance_coins"] == 105
        assert claim_data["is_claimed"] is True

        # 5b. Verify status now reflects is_claimed == True and can_claim == False
        claimed_status = await ac.get(
            "/loyalty/status",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert claimed_status.status_code == 200
        assert claimed_status.json()["is_claimed"] is True
        assert claimed_status.json()["can_claim"] is False

        # 5c. Prevent duplicate claim: second attempt must be rejected with 400
        duplicate_claim = await ac.post(
            "/loyalty/claim",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert duplicate_claim.status_code == 400
        assert "already claimed" in duplicate_claim.json()["detail"].lower()

        # 6. User claims ad-bonus
        ad_bonus_res = await ac.post(
            "/loyalty/ad-bonus",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert ad_bonus_res.status_code == 200
        assert ad_bonus_res.json()["coins_awarded"] >= 5

        # 7. Check my-grants list
        grants_res = await ac.get(
            "/loyalty/my-grants",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert grants_res.status_code == 200
        grants = grants_res.json()
        assert len(grants) >= 2
