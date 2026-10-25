from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.revenue import (
    Creator,
    Payout,
    RevenueSplitRule,
    RevenueTransaction,
)
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.wallet import CoinPurchase


async def _resolve_creator(db: AsyncSession, episode: Episode) -> Optional[Creator]:
    creator_id = episode.creator_id
    if creator_id is None:
        sres = await db.execute(select(Series).where(Series.id == episode.series_id))
        series = sres.scalar_one_or_none()
        if series is None:
            return None
        creator_id = series.creator_id
    if creator_id is None:
        return None
    cres = await db.execute(select(Creator).where(Creator.id == creator_id))
    return cres.scalar_one_or_none()


async def _resolve_split_pct(
    db: AsyncSession,
    creator: Optional[Creator],
    episode: Episode,
    series_id: int,
) -> float:
    res = await db.execute(
        select(RevenueSplitRule)
        .where(
            RevenueSplitRule.creator_id == (creator.id if creator else 0),
            RevenueSplitRule.episode_id == episode.id,
            RevenueSplitRule.is_active.is_(True),
        )
        .limit(1)
    )
    rule = res.scalar_one_or_none()
    if rule is not None:
        return float(rule.creator_share_pct)

    res = await db.execute(
        select(RevenueSplitRule)
        .where(
            RevenueSplitRule.creator_id == (creator.id if creator else 0),
            RevenueSplitRule.series_id == series_id,
            RevenueSplitRule.episode_id.is_(None),
            RevenueSplitRule.is_active.is_(True),
        )
        .limit(1)
    )
    rule = res.scalar_one_or_none()
    if rule is not None:
        return float(rule.creator_share_pct)

    if creator is not None and creator.default_revenue_split_pct is not None:
        return float(creator.default_revenue_split_pct)
    return 50.0


class RevenueService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def calculate_coin_revenue(
        self,
        episode_id: int,
        user_id: int,
        coins_spent: int,
        coin_price_birr: float = 1.0,
        reference: Optional[str] = None,
    ) -> RevenueTransaction:
        ep_res = await self.db.execute(select(Episode).where(Episode.id == episode_id))
        episode = ep_res.scalar_one_or_none()
        if episode is None:
            raise ValueError("Episode not found")

        creator = await _resolve_creator(self.db, episode)
        split_pct = await _resolve_split_pct(self.db, creator, episode, episode.series_id)

        gross = float(Decimal(str(coins_spent)) * Decimal(str(coin_price_birr)))
        creator_share = gross * split_pct / 100.0
        platform_share = gross - creator_share

        tx = RevenueTransaction(
            creator_id=creator.id if creator else None,
            series_id=episode.series_id,
            episode_id=episode.id,
            user_id=user_id,
            source_type="coin_payment",
            gross_amount_birr=gross,
            creator_share_birr=creator_share,
            platform_share_birr=platform_share,
            reference=reference or f"coins:episode:{episode.id}:user:{user_id}",
        )
        self.db.add(tx)
        await self.db.flush()
        return tx

    async def calculate_ad_revenue(
        self,
        episode_id: int,
        user_id: int,
        gross_amount_birr: float = 0.0,
        reference: Optional[str] = None,
    ) -> RevenueTransaction:
        ep_res = await self.db.execute(select(Episode).where(Episode.id == episode_id))
        episode = ep_res.scalar_one_or_none()
        if episode is None:
            raise ValueError("Episode not found")

        tx = RevenueTransaction(
            creator_id=None,
            series_id=episode.series_id,
            episode_id=episode.id,
            user_id=user_id,
            source_type="ad_revenue",
            gross_amount_birr=gross_amount_birr,
            creator_share_birr=0.0,
            platform_share_birr=gross_amount_birr,
            reference=reference or f"ad:episode:{episode.id}:user:{user_id}",
        )
        self.db.add(tx)
        await self.db.flush()
        return tx

    async def calculate_pass_consumption(
        self,
        user_id: int,
        pass_purchase_id: int,
    ) -> List[RevenueTransaction]:
        pp_res = await self.db.execute(
            select(TimePassPurchase).where(TimePassPurchase.id == pass_purchase_id)
        )
        purchase = pp_res.scalar_one_or_none()
        if purchase is None:
            return []

        pass_res = await self.db.execute(select(TimePass).where(TimePass.id == purchase.pass_id))
        time_pass = pass_res.scalar_one_or_none()
        if time_pass is None:
            return []

        price_birr = float(time_pass.price_birr or 0)

        duration_seconds = 0
        if purchase.expires_at and purchase.starts_at:
            duration_seconds = int((purchase.expires_at - purchase.starts_at).total_seconds())
        if duration_seconds <= 0:
            duration_seconds = int(time_pass.duration_hours or 1) * 3600
        duration_seconds = max(duration_seconds, 1)

        rate_per_second = price_birr / float(duration_seconds)

        views_res = await self.db.execute(
            select(ViewLog).where(
                ViewLog.user_id == user_id,
                ViewLog.pass_purchase_id == pass_purchase_id,
                ViewLog.watch_time_seconds >= 60,
            )
        )
        views = views_res.scalars().all()

        per_episode: dict[int, int] = {}
        for v in views:
            per_episode[v.episode_id] = per_episode.get(v.episode_id, 0) + int(v.watch_time_seconds or 0)

        episode_ids = list(per_episode.keys())
        episodes = {}
        if episode_ids:
            eps_res = await self.db.execute(select(Episode).where(Episode.id.in_(episode_ids)))
            episodes = {e.id: e for e in eps_res.scalars().all()}

        total_attributed_gross = 0.0
        txs: List[RevenueTransaction] = []

        raw_gross_by_ep = {
            ep_id: watch_secs * rate_per_second
            for ep_id, watch_secs in per_episode.items()
        }
        sum_raw_gross = sum(raw_gross_by_ep.values())
        scale = 1.0
        if sum_raw_gross > price_birr and sum_raw_gross > 0:
            scale = price_birr / sum_raw_gross

        for ep_id, raw_gross in raw_gross_by_ep.items():
            ep = episodes.get(ep_id)
            if ep is None:
                continue
            creator = await _resolve_creator(self.db, ep)
            split_pct = await _resolve_split_pct(self.db, creator, ep, ep.series_id)

            gross_ep = round(raw_gross * scale, 4)
            creator_share = round(gross_ep * (split_pct / 100.0), 4)
            platform_share = round(gross_ep - creator_share, 4)
            total_attributed_gross += gross_ep

            tx = RevenueTransaction(
                creator_id=creator.id if creator else None,
                series_id=ep.series_id,
                episode_id=ep.id,
                user_id=user_id,
                source_type="pass_consumption",
                gross_amount_birr=gross_ep,
                creator_share_birr=creator_share,
                platform_share_birr=platform_share,
                reference=f"pass:{pass_purchase_id}:ep:{ep.id}:user:{user_id}",
            )
            self.db.add(tx)
            txs.append(tx)

        unconsumed_gross = round(max(price_birr - total_attributed_gross, 0.0), 4)
        if unconsumed_gross > 0 or not txs:
            unconsumed_amount = unconsumed_gross if txs else price_birr
            un_tx = RevenueTransaction(
                creator_id=None,
                series_id=None,
                episode_id=None,
                user_id=user_id,
                source_type="unconsumed_pass",
                gross_amount_birr=unconsumed_amount,
                creator_share_birr=0.0,
                platform_share_birr=unconsumed_amount,
                reference=f"pass:{pass_purchase_id}:unconsumed:user:{user_id}",
            )
            self.db.add(un_tx)
            txs.append(un_tx)

        if txs:
            await self.db.flush()
        return txs

    async def calculate_subscription_consumption(
        self,
        user_id: int,
        subscription_id: int,
    ) -> List[RevenueTransaction]:
        sub_res = await self.db.execute(select(Subscription).where(Subscription.id == subscription_id))
        sub = sub_res.scalar_one_or_none()
        if sub is None:
            return []
        plan_res = await self.db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == sub.plan_id))
        plan = plan_res.scalar_one_or_none()
        if plan is None:
            return []
        price_birr = float(plan.price_birr or 0)

        duration_seconds = 0
        if sub.next_billing_at and sub.started_at:
            duration_seconds = int((sub.next_billing_at - sub.started_at).total_seconds())
        if duration_seconds <= 0:
            duration_seconds = 30 * 86400
        duration_seconds = max(duration_seconds, 1)

        rate_per_second = price_birr / float(duration_seconds)

        views_res = await self.db.execute(
            select(ViewLog).where(
                ViewLog.user_id == user_id,
                ViewLog.subscription_id == subscription_id,
                ViewLog.watch_time_seconds >= 60,
            )
        )
        views = views_res.scalars().all()

        per_episode: dict[int, int] = {}
        for v in views:
            per_episode[v.episode_id] = per_episode.get(v.episode_id, 0) + int(v.watch_time_seconds or 0)

        episode_ids = list(per_episode.keys())
        episodes = {}
        if episode_ids:
            eps_res = await self.db.execute(select(Episode).where(Episode.id.in_(episode_ids)))
            episodes = {e.id: e for e in eps_res.scalars().all()}

        total_attributed_gross = 0.0
        txs: List[RevenueTransaction] = []

        raw_gross_by_ep = {
            ep_id: watch_secs * rate_per_second
            for ep_id, watch_secs in per_episode.items()
        }
        sum_raw_gross = sum(raw_gross_by_ep.values())
        scale = 1.0
        if sum_raw_gross > price_birr and sum_raw_gross > 0:
            scale = price_birr / sum_raw_gross

        for ep_id, raw_gross in raw_gross_by_ep.items():
            ep = episodes.get(ep_id)
            if ep is None:
                continue
            creator = await _resolve_creator(self.db, ep)
            split_pct = await _resolve_split_pct(self.db, creator, ep, ep.series_id)

            gross_ep = round(raw_gross * scale, 4)
            creator_share = round(gross_ep * (split_pct / 100.0), 4)
            platform_share = round(gross_ep - creator_share, 4)
            total_attributed_gross += gross_ep

            tx = RevenueTransaction(
                creator_id=creator.id if creator else None,
                series_id=ep.series_id,
                episode_id=ep.id,
                user_id=user_id,
                source_type="subscription_consumption",
                gross_amount_birr=gross_ep,
                creator_share_birr=creator_share,
                platform_share_birr=platform_share,
                reference=f"subscription:{subscription_id}:ep:{ep.id}:user:{user_id}",
            )
            self.db.add(tx)
            txs.append(tx)

        unconsumed_gross = round(max(price_birr - total_attributed_gross, 0.0), 4)
        if unconsumed_gross > 0 or not txs:
            unconsumed_amount = unconsumed_gross if txs else price_birr
            un_tx = RevenueTransaction(
                creator_id=None,
                series_id=None,
                episode_id=None,
                user_id=user_id,
                source_type="unconsumed_subscription",
                gross_amount_birr=unconsumed_amount,
                creator_share_birr=0.0,
                platform_share_birr=unconsumed_amount,
                reference=f"subscription:{subscription_id}:unconsumed:user:{user_id}",
            )
            self.db.add(un_tx)
            txs.append(un_tx)

        if txs:
            await self.db.flush()
        return txs

    async def get_creator_pending_balance(self, creator_id: int) -> float:
        gross_res = await self.db.execute(
            select(func.coalesce(func.sum(RevenueTransaction.creator_share_birr), 0)).where(
                RevenueTransaction.creator_id == creator_id
            )
        )
        total_share = float(gross_res.scalar_one() or 0)

        paid_res = await self.db.execute(
            select(func.coalesce(func.sum(Payout.amount_birr), 0)).where(
                Payout.creator_id == creator_id,
                Payout.status.in_(("processed", "pending")),
            )
        )
        total_paid = float(paid_res.scalar_one() or 0)
        return max(total_share - total_paid, 0.0)

    async def process_payout(
        self,
        creator_id: int,
        amount_birr: float,
        admin_id: int,
        notes: Optional[str] = None,
    ) -> Payout:
        payout = Payout(
            creator_id=creator_id,
            amount_birr=amount_birr,
            status="pending",
            processed_by_admin_id=admin_id,
            notes=notes,
        )
        self.db.add(payout)
        await self.db.flush()
        return payout


async def check_expired_passes(db: AsyncSession) -> dict:
    now = datetime.now(timezone.utc)
    svc = RevenueService(db)

    pass_res = await db.execute(
        select(TimePassPurchase).where(
            TimePassPurchase.is_active.is_(True),
            TimePassPurchase.revenue_processed.is_(False),
            TimePassPurchase.expires_at < now,
        )
    )
    expired_passes = pass_res.scalars().all()

    sub_res = await db.execute(
        select(Subscription).where(
            Subscription.status == "active",
            Subscription.revenue_processed.is_(False),
            Subscription.next_billing_at < now,
        )
    )
    expired_subs = sub_res.scalars().all()

    total_tx = 0
    for p in expired_passes:
        txs = await svc.calculate_pass_consumption(p.user_id, p.id)
        total_tx += len(txs)
        p.is_active = False
        p.revenue_processed = True

    for s in expired_subs:
        txs = await svc.calculate_subscription_consumption(s.user_id, s.id)
        total_tx += len(txs)
        s.status = "expired"
        s.revenue_processed = True

    await db.flush()
    return {
        "processed_passes": len(expired_passes),
        "processed_subscriptions": len(expired_subs),
        "transactions_created": total_tx,
    }
