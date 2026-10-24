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

    if creator is not None:
        return float(creator.default_revenue_split_pct or 0)
    return 0.0


class RevenueService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def calculate_coin_revenue(
        self,
        episode_id: int,
        user_id: int,
        coins_spent: int,
        coin_price_birr: float,
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
            gross_amount_birr=0,
            creator_share_birr=0,
            platform_share_birr=0,
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

        views_res = await self.db.execute(
            select(ViewLog).where(
                ViewLog.user_id == user_id,
                ViewLog.pass_purchase_id == pass_purchase_id,
            )
        )
        views = views_res.scalars().all()
        if not views:
            return []

        per_episode: dict[int, int] = {}
        for v in views:
            per_episode[v.episode_id] = per_episode.get(v.episode_id, 0) + int(v.watch_time_seconds or 0)

        total_watch = sum(per_episode.values())
        if total_watch <= 0:
            return []

        consumed_value = price_birr

        episode_ids = list(per_episode.keys())
        eps_res = await self.db.execute(select(Episode).where(Episode.id.in_(episode_ids)))
        episodes = {e.id: e for e in eps_res.scalars().all()}

        per_creator_share: dict[int, float] = {}
        for ep_id, watch in per_episode.items():
            ep = episodes.get(ep_id)
            if ep is None:
                continue
            creator = await _resolve_creator(self.db, ep)
            if creator is None:
                continue
            split_pct = await _resolve_split_pct(self.db, creator, ep, ep.series_id)
            share_of_watch = watch / total_watch
            share_value = consumed_value * share_of_watch * (split_pct / 100.0)
            per_creator_share[creator.id] = per_creator_share.get(creator.id, 0.0) + share_value

        txs: List[RevenueTransaction] = []
        for creator_id, creator_share in per_creator_share.items():
            tx = RevenueTransaction(
                creator_id=creator_id,
                series_id=None,
                episode_id=None,
                user_id=user_id,
                source_type="pass_consumption",
                gross_amount_birr=consumed_value,
                creator_share_birr=creator_share,
                platform_share_birr=consumed_value - creator_share,
                reference=f"pass:{pass_purchase_id}:user:{user_id}",
            )
            self.db.add(tx)
            txs.append(tx)
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

        views_res = await self.db.execute(
            select(ViewLog).where(
                ViewLog.user_id == user_id,
                ViewLog.subscription_id == subscription_id,
            )
        )
        views = views_res.scalars().all()
        if not views:
            return []

        per_episode: dict[int, int] = {}
        for v in views:
            per_episode[v.episode_id] = per_episode.get(v.episode_id, 0) + int(v.watch_time_seconds or 0)
        total_watch = sum(per_episode.values())
        if total_watch <= 0:
            return []

        episode_ids = list(per_episode.keys())
        eps_res = await self.db.execute(select(Episode).where(Episode.id.in_(episode_ids)))
        episodes = {e.id: e for e in eps_res.scalars().all()}

        per_creator_share: dict[int, float] = {}
        for ep_id, watch in per_episode.items():
            ep = episodes.get(ep_id)
            if ep is None:
                continue
            creator = await _resolve_creator(self.db, ep)
            if creator is None:
                continue
            split_pct = await _resolve_split_pct(self.db, creator, ep, ep.series_id)
            share_of_watch = watch / total_watch
            share_value = price_birr * share_of_watch * (split_pct / 100.0)
            per_creator_share[creator.id] = per_creator_share.get(creator.id, 0.0) + share_value

        txs: List[RevenueTransaction] = []
        for creator_id, creator_share in per_creator_share.items():
            tx = RevenueTransaction(
                creator_id=creator_id,
                series_id=None,
                episode_id=None,
                user_id=user_id,
                source_type="subscription_consumption",
                gross_amount_birr=price_birr,
                creator_share_birr=creator_share,
                platform_share_birr=price_birr - creator_share,
                reference=f"subscription:{subscription_id}:user:{user_id}",
            )
            self.db.add(tx)
            txs.append(tx)
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
