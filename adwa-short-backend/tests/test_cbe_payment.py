from __future__ import annotations

import json
from datetime import timedelta
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.cbe_payment import CbePaymentOrder
from app.models.revenue import RevenueTransaction
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.wallet import CoinPackage, CoinPurchase, Wallet
from app.services.cbe_gateway import cbe_gateway
from app.utils.time import utcnow


@pytest.mark.asyncio
async def test_cbe_initiate_coins_checkout(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    headers = auth_headers

    # 1. Create active coin package
    from app.database import AsyncSessionLocal
    async with AsyncSessionLocal() as s:
        pkg = CoinPackage(
            name="100 Coins Pack",
            coins=100,
            price_birr=80.0,
            episodes_unlocked=10,
            is_active=True,
            sort_order=1,
        )
        s.add(pkg)
        await s.commit()
        await s.refresh(pkg)
        pkg_id = pkg.id

    # 2. Initiate payment
    init_res = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "coins", "item_id": pkg_id, "phone": "+251911223344"},
        headers=headers,
    )
    assert init_res.status_code == 201, init_res.text
    data = init_res.json()
    assert "CBE-ORD-" in data["order_id"]
    assert data["amount_birr"] == 80.0
    assert data["currency"] == "ETB"
    assert data["status"] == "pending"
    assert "CBE" in data["bill_reference"]
    assert "checkout.cbe.com.et" in data["checkout_url"]
    assert "*847*1*" in data["ussd_code"]

    # 3. Check order in DB
    async with AsyncSessionLocal() as s:
        res = await s.execute(select(CbePaymentOrder).where(CbePaymentOrder.order_id == data["order_id"]))
        order = res.scalar_one_or_none()
        assert order is not None
        assert order.status == "pending"
        assert order.amount_birr == 80.0
        assert order.user_id == user.id


@pytest.mark.asyncio
async def test_cbe_webhook_verification_and_coins_fulfillment(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    headers = auth_headers

    from app.database import AsyncSessionLocal
    async with AsyncSessionLocal() as s:
        pkg = CoinPackage(
            name="500 Mega Coins",
            coins=500,
            price_birr=350.0,
            episodes_unlocked=50,
            is_active=True,
            sort_order=2,
        )
        s.add(pkg)
        await s.commit()
        await s.refresh(pkg)
        pkg_id = pkg.id

    init_res = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "coins", "item_id": pkg_id},
        headers=headers,
    )
    assert init_res.status_code == 201, init_res.text
    order_id = init_res.json()["order_id"]

    # Initial wallet coins
    async with AsyncSessionLocal() as s:
        w_res = await s.execute(select(Wallet).where(Wallet.user_id == user.id))
        init_coins = w_res.scalar_one().balance_coins

    # Test invalid signature rejection
    fake_body = {
        "order_id": order_id,
        "cbe_transaction_id": "TX-FORGED-1234",
        "amount_birr": 350.0,
        "status": "COMPLETED",
    }
    bad_res = await client.post(
        "/api/v1/payments/cbe/webhook",
        json=fake_body,
        headers={"X-CBE-Signature": "invalid_forged_signature_hash"},
    )
    assert bad_res.status_code == 401

    # Test valid cryptographic signature
    mock_payload, valid_sig = cbe_gateway.build_simulation_webhook(
        order_id=order_id,
        amount_birr=350.0,
        cbe_transaction_id="TX-CBE-VERIFIED-9999",
    )

    good_res = await client.post(
        "/api/v1/payments/cbe/webhook",
        json=mock_payload,
        headers={"X-CBE-Signature": valid_sig},
    )
    assert good_res.status_code == 200, good_res.text
    res_data = good_res.json()
    assert res_data["status"] == "success"
    assert res_data["order_id"] == order_id
    assert res_data["amount_birr"] == 350.0
    assert res_data["creator_pool_reserve_birr"] == 175.0  # 50% reserve
    assert res_data["platform_share_birr"] == 175.0        # 50% platform

    # Verify wallet coins incremented
    async with AsyncSessionLocal() as s:
        w_res = await s.execute(select(Wallet).where(Wallet.user_id == user.id))
        updated_wallet = w_res.scalar_one()
        assert updated_wallet.balance_coins == init_coins + 500

        # Verify CoinPurchase recorded
        cp_res = await s.execute(select(CoinPurchase).where(CoinPurchase.user_id == user.id))
        purchases = cp_res.scalars().all()
        assert any(p.package_id == pkg_id and p.coins == 500 for p in purchases)

        # Verify RevenueTransaction created with segregation
        rt_res = await s.execute(
            select(RevenueTransaction).where(RevenueTransaction.reference == f"cbe:{order_id}:tx:TX-CBE-VERIFIED-9999")
        )
        rev = rt_res.scalar_one_or_none()
        assert rev is not None
        assert rev.source_type == "cbe_coins"
        assert rev.gross_amount_birr == 350.0
        assert rev.creator_share_birr == 175.0
        assert rev.platform_share_birr == 175.0


@pytest.mark.asyncio
async def test_cbe_webhook_idempotency_prevents_double_crediting(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    headers = auth_headers

    from app.database import AsyncSessionLocal
    async with AsyncSessionLocal() as s:
        pkg = CoinPackage(name="Single Pack", coins=50, price_birr=40.0, is_active=True)
        s.add(pkg)
        await s.commit()
        await s.refresh(pkg)
        pkg_id = pkg.id

    init_res = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "coins", "item_id": pkg_id},
        headers=headers,
    )
    assert init_res.status_code == 201, init_res.text
    order_id = init_res.json()["order_id"]

    mock_payload, valid_sig = cbe_gateway.build_simulation_webhook(
        order_id=order_id,
        amount_birr=40.0,
        cbe_transaction_id="TX-IDEMPOTENT-001",
    )

    # First webhook submission: succeeds
    res1 = await client.post(
        "/api/v1/payments/cbe/webhook",
        json=mock_payload,
        headers={"X-CBE-Signature": valid_sig},
    )
    assert res1.status_code == 200
    assert res1.json()["status"] == "success"

    # Get balance after first credit
    async with AsyncSessionLocal() as s:
        w_res = await s.execute(select(Wallet).where(Wallet.user_id == user.id))
        balance_after_first = w_res.scalar_one().balance_coins

    # Second webhook submission with same order_id: must be recognized as idempotent
    res2 = await client.post(
        "/api/v1/payments/cbe/webhook",
        json=mock_payload,
        headers={"X-CBE-Signature": valid_sig},
    )
    assert res2.status_code == 200
    assert res2.json()["status"] == "already_processed"

    # Confirm balance DID NOT increase again!
    async with AsyncSessionLocal() as s:
        w_res = await s.execute(select(Wallet).where(Wallet.user_id == user.id))
        balance_after_second = w_res.scalar_one().balance_coins
        assert balance_after_second == balance_after_first


@pytest.mark.asyncio
async def test_cbe_time_pass_and_subscription_fulfillment(client: AsyncClient, demo_user, auth_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user
    headers = auth_headers

    from app.database import AsyncSessionLocal
    async with AsyncSessionLocal() as s:
        tpass = TimePass(name="24-Hour Pass", duration_hours=24, price_birr=60.0, is_active=True)
        sub_plan = SubscriptionPlan(name="Monthly VIP", billing_cycle="monthly", price_birr=120.0, is_active=True)
        s.add_all([tpass, sub_plan])
        await s.commit()
        await s.refresh(tpass)
        await s.refresh(sub_plan)
        pass_id, plan_id = tpass.id, sub_plan.id

    # 1. Purchase Time Pass via CBE
    pass_init = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "time_pass", "item_id": pass_id},
        headers=headers,
    )
    assert pass_init.status_code == 201, pass_init.text
    pass_order_id = pass_init.json()["order_id"]

    # Fulfill via simulation endpoint
    sim_res = await client.post(f"/api/v1/payments/cbe/simulate-payment/{pass_order_id}")
    assert sim_res.status_code == 200
    assert sim_res.json()["status"] == "success"

    # Check TimePassPurchase exists and is active
    async with AsyncSessionLocal() as s:
        tpp_res = await s.execute(
            select(TimePassPurchase).where(
                TimePassPurchase.user_id == user.id,
                TimePassPurchase.pass_id == pass_id,
            )
        )
        purchase = tpp_res.scalar_one_or_none()
        assert purchase is not None
        assert purchase.is_active is True

    # 2. Purchase Subscription via CBE
    sub_init = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "subscription", "item_id": plan_id},
        headers=headers,
    )
    assert sub_init.status_code == 201, sub_init.text
    sub_order_id = sub_init.json()["order_id"]

    sim_sub = await client.post(f"/api/v1/payments/cbe/simulate-payment/{sub_order_id}")
    assert sim_sub.status_code == 200
    assert sim_sub.json()["status"] == "success"

    # Check Subscription exists and is active
    async with AsyncSessionLocal() as s:
        sub_res = await s.execute(
            select(Subscription).where(
                Subscription.user_id == user.id,
                Subscription.plan_id == plan_id,
            )
        )
        subscription = sub_res.scalar_one_or_none()
        assert subscription is not None
        assert subscription.status == "active"


@pytest.mark.asyncio
async def test_cbe_status_polling_and_admin_orders(client: AsyncClient, demo_user, auth_headers, admin_headers):
    user = demo_user[0] if isinstance(demo_user, tuple) else demo_user

    # Initiate deposit
    init_res = await client.post(
        "/api/v1/payments/cbe/initiate",
        json={"item_type": "wallet_deposit", "amount_birr": 200.0},
        headers=auth_headers,
    )
    assert init_res.status_code == 201, init_res.text
    order_id = init_res.json()["order_id"]

    # Poll status (initially pending)
    poll_res = await client.get(f"/api/v1/payments/cbe/order/{order_id}")
    assert poll_res.status_code == 200
    assert poll_res.json()["status"] == "pending"

    # Complete via simulation
    await client.post(f"/api/v1/payments/cbe/simulate-payment/{order_id}")

    # Poll status again (now completed)
    poll_res2 = await client.get(f"/api/v1/payments/cbe/order/{order_id}")
    assert poll_res2.status_code == 200
    assert poll_res2.json()["status"] == "completed"

    # Super Admin can list all CBE orders
    admin_orders_res = await client.get(
        "/api/v1/payments/cbe/admin/orders",
        headers=admin_headers,
    )
    assert admin_orders_res.status_code == 200
    orders = admin_orders_res.json()
    assert len(orders) >= 1
    assert any(o["order_id"] == order_id for o in orders)


@pytest.mark.asyncio
async def test_platform_treasury_endpoint_and_balance(client: AsyncClient, admin_headers):
    # Verify Platform Treasury endpoint reflects official Commercial Bank of Ethiopia (CBE) infrastructure
    res = await client.get("/admin/revenue/treasury", headers=admin_headers)
    assert res.status_code == 200, res.text
    data = res.json()

    assert data["treasury_account_number"] == "1000293847561"
    assert data["treasury_account_name"] == "ADWA SHORT ENTERTAINMENT PLATFORM"
    assert data["treasury_bank_name"] == "Commercial Bank of Ethiopia (CBE)"
    assert data["treasury_branch"] == "Finfine Branch / Head Office"
    assert "total_platform_revenue_birr" in data
    assert "total_creator_earnings_birr" in data
    assert "total_creator_disbursed_birr" in data
    assert "treasury_retained_balance_birr" in data
    assert "subscriptions_retained_birr" in data
    assert "unconsumed_passes_retained_birr" in data
    assert "ad_revenues_retained_birr" in data
    assert "content_split_fees_retained_birr" in data


@pytest.mark.asyncio
async def test_creator_cbe_payout_disbursement_and_ledger(client: AsyncClient, admin_headers):
    from app.database import AsyncSessionLocal
    from app.models.revenue import Creator, Payout, RevenueTransaction

    # 1. Seed creator with verified Commercial Bank of Ethiopia (CBE) account
    async with AsyncSessionLocal() as s:
        creator = Creator(
            name="CBE Test Creator",
            bank_account_name="CBE Test Creator Holder",
            bank_account_number="1000987654321",
            bank_name="Commercial Bank of Ethiopia (CBE)",
            payment_method="cbe",
            default_revenue_split_pct=60.0,
            is_active=True,
        )
        s.add(creator)
        await s.commit()
        await s.refresh(creator)
        creator_id = creator.id

        # Add revenue transaction to credit creator balance
        rev_tx = RevenueTransaction(
            creator_id=creator_id,
            source_type="coin_payment",
            gross_amount_birr=500.0,
            creator_share_birr=300.0,
            platform_share_birr=200.0,
            reference=f"coins:test:creator:{creator_id}",
        )
        s.add(rev_tx)
        await s.commit()

    # 2. Super Admin creates a payout for the creator
    payout_res = await client.post(
        f"/creators/{creator_id}/payouts",
        json={"amount_birr": 150.0, "notes": "CBE Treasury Disbursed Payout"},
        headers=admin_headers,
    )
    assert payout_res.status_code == 201, payout_res.text
    payout_data = payout_res.json()

    assert payout_data["amount_birr"] == 150.0
    assert payout_data["status"] == "processed"
    assert payout_data["cbe_payout_status"] == "completed"
    assert payout_data["cbe_transaction_id"] is not None
    assert payout_data["cbe_transaction_id"].startswith("CBE-B2C-")
    assert payout_data["bank_account_number"] == "1000987654321"
    assert payout_data["bank_account_name"] == "CBE Test Creator Holder"
    assert payout_data["bank_name"] == "Commercial Bank of Ethiopia (CBE)"
    assert payout_data["treasury_account_number"] == "1000293847561"
    payout_id = payout_data["id"]

    # 3. Verify Payouts Audit Endpoint reflects the CBE fields
    audit_res = await client.get("/admin/revenue/payouts", headers=admin_headers)
    assert audit_res.status_code == 200
    payouts_list = audit_res.json()
    matching = [p for p in payouts_list if p["id"] == payout_id]
    assert len(matching) == 1
    m = matching[0]
    assert m["cbe_transaction_id"] == payout_data["cbe_transaction_id"]
    assert m["bank_account_number"] == "1000987654321"
    assert m["treasury_account_number"] == "1000293847561"

    # 4. Test manual trigger / retry disburse endpoint
    retry_res = await client.post(f"/admin/revenue/payouts/{payout_id}/disburse", headers=admin_headers)
    assert retry_res.status_code == 200, retry_res.text
    assert retry_res.json()["status"] == "success"
