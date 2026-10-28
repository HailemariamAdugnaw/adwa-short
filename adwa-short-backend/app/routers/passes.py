from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction
from app.models.subscription import TimePass, TimePassPurchase
from app.schemas.subscription import (
    ActivePassStatus,
    TimePassCreate,
    TimePassOut,
    TimePassPurchaseOut,
    TimePassPurchaseRequest,
    TimePassUpdate,
)
from app.services.monetization import get_user_active_pass
from app.utils.time import ensure_utc, utcnow

router = APIRouter(prefix="/passes", tags=["passes"])


@router.get("", response_model=List[TimePassOut])
async def list_passes(db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(TimePass).where(TimePass.is_active.is_(True)).order_by(TimePass.sort_order)
    )
    return list(res.scalars().all())


@router.get("/active", response_model=ActivePassStatus)
async def get_active_pass_endpoint(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Returns the user's currently active Time Pass with exact server-calculated remaining seconds."""
    now = utcnow()
    active = await get_user_active_pass(db, user.id)
    if active is None or ensure_utc(active.expires_at) <= now:
        return ActivePassStatus(has_active_pass=False, server_time=now, remaining_seconds=0)

    exp_utc = ensure_utc(active.expires_at)
    remaining = max(0, int((exp_utc - now).total_seconds()))
    p_name = active.pass_.name if active.pass_ else "Time Pass"
    p_hours = active.pass_.duration_hours if active.pass_ else None
    p_price = float(active.pass_.price_birr) if active.pass_ else None

    return ActivePassStatus(
        has_active_pass=True,
        purchase_id=active.id,
        pass_id=active.pass_id,
        name=p_name,
        duration_hours=p_hours,
        price_birr=p_price,
        starts_at=ensure_utc(active.starts_at),
        expires_at=exp_utc,
        is_active=True,
        server_time=now,
        remaining_seconds=remaining,
    )


@router.get("/my", response_model=List[TimePassPurchaseOut])
async def my_passes(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = utcnow()
    # Expire outdated passes for this user
    stale_res = await db.execute(
        select(TimePassPurchase).where(
            TimePassPurchase.user_id == user.id,
            TimePassPurchase.is_active.is_(True),
            TimePassPurchase.expires_at <= now,
        )
    )
    for sp in stale_res.scalars().all():
        sp.is_active = False
    await db.flush()

    res = await db.execute(
        select(TimePassPurchase).where(TimePassPurchase.user_id == user.id).order_by(TimePassPurchase.created_at.desc())
    )
    return list(res.scalars().all())


@router.post("/purchase", response_model=TimePassPurchaseOut, status_code=status.HTTP_201_CREATED)
async def purchase_pass(
    payload: TimePassPurchaseRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(TimePass).where(TimePass.id == payload.pass_id))
    p = res.scalar_one_or_none()
    if p is None or not p.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pass not found")

    wres = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet = wres.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user.id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()

    if float(wallet.balance_birr) < float(p.price_birr):
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Insufficient Birr balance")

    wallet.balance_birr = float(wallet.balance_birr) - float(p.price_birr)
    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="purchase",
            amount_birr=-float(p.price_birr),
            amount_coins=0,
            description=f"Purchased {p.name}",
            reference=f"timepass:{p.id}",
        )
    )

    now = utcnow()
    # Time Pass Repurchase / Stacking:
    # If the user already has an active pass, extend/stack duration onto the existing expiry.
    active_pass = await get_user_active_pass(db, user.id)
    base_time = ensure_utc(active_pass.expires_at) if (active_pass and ensure_utc(active_pass.expires_at) > now) else now
    duration_hours = max(1, int(p.duration_hours))
    new_expires_at = base_time + timedelta(hours=duration_hours)

    purchase = TimePassPurchase(
        user_id=user.id,
        pass_id=p.id,
        starts_at=now,
        expires_at=new_expires_at,
        is_active=True,
    )
    db.add(purchase)
    await db.commit()
    await db.refresh(purchase)
    return purchase


@router.post("", response_model=TimePassOut, status_code=status.HTTP_201_CREATED)
async def create_pass(
    payload: TimePassCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    p = TimePass(**payload.model_dump())
    db.add(p)
    await db.commit()
    await db.refresh(p)
    return p


@router.put("/{pass_id}", response_model=TimePassOut)
async def update_pass(
    pass_id: int,
    payload: TimePassUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(TimePass).where(TimePass.id == pass_id))
    p = res.scalar_one_or_none()
    if p is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pass not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(p, k, v)
    await db.commit()
    await db.refresh(p)
    return p


@router.delete("/{pass_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_pass(
    pass_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(TimePass).where(TimePass.id == pass_id))
    p = res.scalar_one_or_none()
    if p is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pass not found")
    await db.delete(p)
    await db.commit()
