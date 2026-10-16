from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.revenue import Creator, RevenueTransaction
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.user import User
from app.models.wallet import Wallet
from app.services.revenue import RevenueService, check_expired_passes

pytestmark = pytest.mark.asyncio


async def _seed_episode_with_creator(creator_split: float = 50.0) -> tuple[int, int, int]:
    async with AsyncSessionLocal() as s:
        creator = Creator(name="Rev Creator", default_revenue_split_pct=creator_split, is_active=True)
        s.add(creator)
        await s.flush()
        series = Series(
            title="Rev Series",
            type="series",
            is_published=True,
            free_episode_count=1,
            total_episodes=2,
            creator_id=creator.id,
        )
        s.add(series)
        await s.flush()
        ep = Episode(
            series_id=series.id,
            creator_id=creator.id,
            episode_number=2,
            title="Rev E2",
            coin_cost=10,
            is_published=True,
            published_at=datetime.now(timezone.utc),
        )
        s.add(ep)
        u = User(
            phone="+251970000001",
            password_hash="x",
            display_name="Rev User",
            role="user",
            is_active=True,
        )
        s.add(u)
        await s.flush()
        s.add(Wallet(user_id=u.id, balance_birr=0, balance_coins=0))
        await s.commit()
        return creator.id, ep.id, u.id


async def test_calculate_coin_revenue():
    creator_id, ep_id, user_id = await _seed_episode_with_creator(creator_split=50.0)
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        tx = await svc.calculate_coin_revenue(ep_id, user_id, coins_spent=10, coin_price_birr=1.0)
        await s.commit()
        assert tx.gross_amount_birr == 10.0
        assert tx.creator_share_birr == 5.0
        assert tx.platform_share_birr == 5.0
        assert tx.source_type == "coin_payment"
        assert tx.creator_id == creator_id


async def test_calculate_coin_revenue_with_custom_split():
    creator_id, ep_id, user_id = await _seed_episode_with_creator(creator_split=60.0)
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        tx = await svc.calculate_coin_revenue(ep_id, user_id, coins_spent=100, coin_price_birr=2.0)
        await s.commit()
        assert tx.gross_amount_birr == 200.0
        assert tx.creator_share_birr == 120.0
        assert tx.platform_share_birr == 80.0


async def test_calculate_ad_revenue():
    _, ep_id, user_id = await _seed_episode_with_creator()
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        tx = await svc.calculate_ad_revenue(ep_id, user_id)
        await s.commit()
        assert tx.source_type == "ad_revenue"
        assert tx.creator_share_birr == 0
        assert tx.gross_amount_birr == 0


async def test_get_creator_pending_balance():
    creator_id, ep_id, user_id = await _seed_episode_with_creator(creator_split=50.0)
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        await svc.calculate_coin_revenue(ep_id, user_id, coins_spent=10, coin_price_birr=1.0)
        await s.commit()
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        bal = await svc.get_creator_pending_balance(creator_id)
        assert bal == 5.0


async def test_process_payout_reduces_balance():
    creator_id, ep_id, user_id = await _seed_episode_with_creator(creator_split=50.0)
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        await svc.calculate_coin_revenue(ep_id, user_id, coins_spent=10, coin_price_birr=1.0)
        payout = await svc.process_payout(creator_id, amount_birr=2.0, admin_id=1, notes="x")
        await s.commit()
        assert payout.amount_birr == 2.0
        assert payout.status == "pending"

    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        bal = await svc.get_creator_pending_balance(creator_id)
        assert bal == 3.0


async def _seed_pass_with_views() -> tuple[int, int, int, int]:
    creator_id, ep_id, user_id = await _seed_episode_with_creator(creator_split=50.0)
    async with AsyncSessionLocal() as s:
        creator2 = Creator(name="Rev Creator 2", default_revenue_split_pct=50.0, is_active=True)
        s.add(creator2)
        await s.flush()
        series2 = Series(
            title="Rev Series 2",
            type="series",
            is_published=True,
            free_episode_count=0,
            total_episodes=1,
            creator_id=creator2.id,
        )
        s.add(series2)
        await s.flush()
        ep2 = Episode(
            series_id=series2.id,
            creator_id=creator2.id,
            episode_number=1,
            title="Rev E2b",
            coin_cost=10,
            is_published=True,
            published_at=datetime.now(timezone.utc),
        )
        s.add(ep2)
        await s.flush()

        tp = TimePass(name="TP", duration_hours=1, price_birr=100.0, is_active=True)
        s.add(tp)
        await s.flush()
        now = datetime.now(timezone.utc)
        purchase = TimePassPurchase(
            user_id=user_id,
            pass_id=tp.id,
            starts_at=now - timedelta(hours=2),
            expires_at=now - timedelta(hours=1),
            is_active=True,
        )
        s.add(purchase)
        await s.flush()

        s.add(
            ViewLog(
                user_id=user_id,
                episode_id=ep_id,
                series_id=None,
                watch_time_seconds=60,
                pass_purchase_id=purchase.id,
            )
        )
        s.add(
            ViewLog(
                user_id=user_id,
                episode_id=ep2.id,
                series_id=None,
                watch_time_seconds=40,
                pass_purchase_id=purchase.id,
            )
        )
        await s.commit()
        return creator_id, creator2.id, purchase.id, user_id


async def test_calculate_pass_consumption_prorates_by_watch_time():
    c1, c2, purchase_id, user_id = await _seed_pass_with_views()
    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        txs = await svc.calculate_pass_consumption(user_id, purchase_id)
        await s.commit()
        assert len(txs) == 2
        total_creator_share = sum(float(t.creator_share_birr) for t in txs)
        assert 0 < total_creator_share <= 50.0
        for t in txs:
            assert t.source_type == "pass_consumption"
            assert t.gross_amount_birr == 100.0


async def test_calculate_pass_consumption_no_views_returns_empty():
    creator_id, ep_id, user_id = await _seed_episode_with_creator()
    async with AsyncSessionLocal() as s:
        tp = TimePass(name="TP2", duration_hours=1, price_birr=50.0, is_active=True)
        s.add(tp)
        await s.flush()
        now = datetime.now(timezone.utc)
        purchase = TimePassPurchase(
            user_id=user_id,
            pass_id=tp.id,
            starts_at=now - timedelta(hours=2),
            expires_at=now - timedelta(hours=1),
            is_active=True,
        )
        s.add(purchase)
        await s.commit()
        pid = purchase.id
        uid = user_id

    async with AsyncSessionLocal() as s:
        svc = RevenueService(s)
        txs = await svc.calculate_pass_consumption(uid, pid)
        await s.commit()
        assert txs == []


async def test_check_expired_passes_marks_inactive():
    c1, c2, purchase_id, user_id = await _seed_pass_with_views()
    async with AsyncSessionLocal() as s:
        result = await check_expired_passes(s)
        await s.commit()
        assert result["processed_passes"] >= 1
        assert result["transactions_created"] >= 2

    async with AsyncSessionLocal() as s:
        purchase = (
            await s.execute(select(TimePassPurchase).where(TimePassPurchase.id == purchase_id))
        ).scalar_one()
        assert purchase.is_active is False
        assert purchase.revenue_processed is True


async def test_admin_revenue_overview(client, admin_headers):
    res = await client.get("/admin/revenue/overview", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert "total_gross_birr" in body
    assert "total_creator_share_birr" in body
    assert "total_platform_share_birr" in body
    assert "total_pending_balance_birr" in body


async def test_admin_revenue_transactions_filter(client, admin_headers):
    _, _, _ = await _seed_episode_with_creator(creator_split=50.0)
    res = await client.get(
        "/admin/revenue/transactions?source_type=coin_payment",
        headers=admin_headers,
    )
    assert res.status_code == 200
    body = res.json()
    assert isinstance(body, list)


async def test_admin_process_expired(client, admin_headers):
    await _seed_pass_with_views()
    res = await client.post("/admin/revenue/process-expired", headers=admin_headers)
    assert res.status_code == 200
    body = res.json()
    assert "processed_passes" in body
    assert "transactions_created" in body
