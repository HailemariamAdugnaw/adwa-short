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
    SubscribeRequest,
    SubscriptionOut,
    SubscriptionPlanCreate,
    SubscriptionPlanOut,
    SubscriptionPlanUpdate,
)
from app.utils.time import utcnow

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.get("/plans", response_model=List[SubscriptionPlanOut])
async def list_plans(db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.is_active.is_(True))
    )
    return list(res.scalars().all())


@router.get("/my", response_model=List[SubscriptionOut])
async def my_subscriptions(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
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
