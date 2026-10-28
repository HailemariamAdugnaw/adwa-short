from __future__ import annotations

from datetime import timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction
from app.models.subscription import Subscription, SubscriptionPlan
from app.schemas.subscription import (
    ActivePassStatus,
    ActiveSubscriptionStatus,
    SubscribeRequest,
    SubscriptionOut,
    SubscriptionPlanCreate,
    SubscriptionPlanOut,
    SubscriptionPlanUpdate,
    UserAccessDashboardOut,
)
from app.services.monetization import get_user_active_pass, get_user_active_subscription
from app.utils.time import ensure_utc, utcnow

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.get("/plans", response_model=List[SubscriptionPlanOut])
async def list_plans(db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.is_active.is_(True))
    )
    return list(res.scalars().all())


@router.get("/active", response_model=ActiveSubscriptionStatus)
async def get_active_subscription_endpoint(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Returns the user's currently active Subscription with exact server-calculated remaining seconds."""
    now = utcnow()
    active = await get_user_active_subscription(db, user.id)
    if active is None or ensure_utc(active.next_billing_at) <= now:
        return ActiveSubscriptionStatus(has_active_subscription=False, server_time=now, remaining_seconds=0)

    next_billing_utc = ensure_utc(active.next_billing_at)
    remaining = max(0, int((next_billing_utc - now).total_seconds()))
    p_name = active.plan.name if active.plan else "Subscription"
    p_cycle = active.plan.billing_cycle if active.plan else "monthly"
    p_price = float(active.plan.price_birr) if active.plan else None

    return ActiveSubscriptionStatus(
        has_active_subscription=True,
        subscription_id=active.id,
        plan_id=active.plan_id,
        plan_name=p_name,
        billing_cycle=p_cycle,
        price_birr=p_price,
        status=active.status,
        started_at=ensure_utc(active.started_at),
        next_billing_at=next_billing_utc,
        server_time=now,
        remaining_seconds=remaining,
    )


@router.get("/user-access", response_model=UserAccessDashboardOut)
async def get_user_access_dashboard(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Unified user access dashboard returning both active pass and active subscription status with server UTC time."""
    now = utcnow()
    active_p = await get_user_active_pass(db, user.id)
    if active_p is not None and ensure_utc(active_p.expires_at) > now:
        exp_p = ensure_utc(active_p.expires_at)
        rem_p = max(0, int((exp_p - now).total_seconds()))
        pass_status = ActivePassStatus(
            has_active_pass=True,
            purchase_id=active_p.id,
            pass_id=active_p.pass_id,
            name=active_p.pass_.name if active_p.pass_ else "Time Pass",
            duration_hours=active_p.pass_.duration_hours if active_p.pass_ else None,
            price_birr=float(active_p.pass_.price_birr) if active_p.pass_ else None,
            starts_at=ensure_utc(active_p.starts_at),
            expires_at=exp_p,
            is_active=True,
            server_time=now,
            remaining_seconds=rem_p,
        )
    else:
        pass_status = ActivePassStatus(has_active_pass=False, server_time=now, remaining_seconds=0)

    active_s = await get_user_active_subscription(db, user.id)
    if active_s is not None and ensure_utc(active_s.next_billing_at) > now:
        exp_s = ensure_utc(active_s.next_billing_at)
        rem_s = max(0, int((exp_s - now).total_seconds()))
        sub_status = ActiveSubscriptionStatus(
            has_active_subscription=True,
            subscription_id=active_s.id,
            plan_id=active_s.plan_id,
            plan_name=active_s.plan.name if active_s.plan else "Subscription",
            billing_cycle=active_s.plan.billing_cycle if active_s.plan else "monthly",
            price_birr=float(active_s.plan.price_birr) if active_s.plan else None,
            status=active_s.status,
            started_at=ensure_utc(active_s.started_at),
            next_billing_at=exp_s,
            server_time=now,
            remaining_seconds=rem_s,
        )
    else:
        sub_status = ActiveSubscriptionStatus(has_active_subscription=False, server_time=now, remaining_seconds=0)

    return UserAccessDashboardOut(
        server_time=now,
        active_pass=pass_status,
        active_subscription=sub_status,
    )


@router.get("/my", response_model=List[SubscriptionOut])
async def my_subscriptions(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = utcnow()
    # Expire outdated active subscriptions for this user
    stale_res = await db.execute(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.status == "active",
            Subscription.next_billing_at <= now,
        )
    )
    for ss in stale_res.scalars().all():
        ss.status = "expired"
    await db.flush()

    res = await db.execute(
        select(Subscription).where(Subscription.user_id == user.id).order_by(Subscription.created_at.desc())
    )
    return list(res.scalars().all())


@router.post("/subscribe", response_model=SubscriptionOut, status_code=status.HTTP_201_CREATED)
async def subscribe(
    payload: SubscribeRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Guard against duplicate subscription purchases
    active_sub = await get_user_active_subscription(db, user.id)
    if active_sub is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"You already have an active subscription ({active_sub.plan.name if active_sub.plan else 'Active'}). Please manage or cancel your existing subscription first.",
        )

    res = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == payload.plan_id))
    plan = res.scalar_one_or_none()
    if plan is None or not plan.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")

    wres = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet = wres.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user.id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()
    if float(wallet.balance_birr) < float(plan.price_birr):
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Insufficient Birr balance")

    wallet.balance_birr = float(wallet.balance_birr) - float(plan.price_birr)
    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="purchase",
            amount_birr=-float(plan.price_birr),
            amount_coins=0,
            description=f"Subscribed to {plan.name}",
            reference=f"plan:{plan.id}",
        )
    )

    now = utcnow()
    days = 30 if plan.billing_cycle == "monthly" else 365
    sub = Subscription(
        user_id=user.id,
        plan_id=plan.id,
        status="active",
        started_at=now,
        next_billing_at=now + timedelta(days=days),
    )
    db.add(sub)
    await db.commit()
    await db.refresh(sub)
    return sub


@router.post("/cancel/{subscription_id}", response_model=SubscriptionOut)
async def cancel(
    subscription_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Subscription).where(Subscription.id == subscription_id, Subscription.user_id == user.id))
    sub = res.scalar_one_or_none()
    if sub is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subscription not found")
    sub.status = "canceled"
    sub.canceled_at = utcnow()
    await db.commit()
    await db.refresh(sub)
    return sub


@router.post("/unsubscribe", response_model=SubscriptionOut)
async def unsubscribe_active(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Cancels/unsubscribes the user's currently active subscription."""
    active_sub = await get_user_active_subscription(db, user.id)
    if active_sub is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active subscription found to cancel.")
    active_sub.status = "canceled"
    active_sub.canceled_at = utcnow()
    await db.commit()
    await db.refresh(active_sub)
    return active_sub


@router.post("/plans", response_model=SubscriptionPlanOut, status_code=status.HTTP_201_CREATED)
async def create_plan(
    payload: SubscriptionPlanCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    plan = SubscriptionPlan(**payload.model_dump())
    db.add(plan)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.put("/plans/{plan_id}", response_model=SubscriptionPlanOut)
async def update_plan(
    plan_id: int,
    payload: SubscriptionPlanUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = res.scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(plan, k, v)
    await db.commit()
    await db.refresh(plan)
    return plan


@router.delete("/plans/{plan_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plan(
    plan_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = res.scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")
    await db.delete(plan)
    await db.commit()
