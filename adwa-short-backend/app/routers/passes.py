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
    TimePassCreate,
    TimePassOut,
    TimePassPurchaseOut,
    TimePassPurchaseRequest,
    TimePassUpdate,
)
from app.utils.time import utcnow

router = APIRouter(prefix="/passes", tags=["passes"])


@router.get("", response_model=List[TimePassOut])
async def list_passes(db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(TimePass).where(TimePass.is_active.is_(True)).order_by(TimePass.sort_order)
    )
    return list(res.scalars().all())


@router.get("/my", response_model=List[TimePassPurchaseOut])
async def my_passes(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
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
    purchase = TimePassPurchase(
        user_id=user.id,
        pass_id=p.id,
        starts_at=now,
        expires_at=now + timedelta(hours=int(p.duration_hours)),
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
