from __future__ import annotations

import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction
from app.schemas.user import WalletOut, WalletTxOut
from app.schemas.wallet import DepositRequest, DepositResponse
from app.services.loyalty_engine import maybe_grant

router = APIRouter(prefix="/wallet", tags=["wallet"])


async def _get_or_create_wallet(db: AsyncSession, user_id: int) -> Wallet:
    res = await db.execute(select(Wallet).where(Wallet.user_id == user_id))
    wallet = res.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user_id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()
    return wallet


@router.get("", response_model=WalletOut)
async def get_wallet(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    wallet = await _get_or_create_wallet(db, user.id)
    await db.commit()
    return wallet


@router.get("/transactions", response_model=List[WalletTxOut])
async def list_transactions(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    wallet = await _get_or_create_wallet(db, user.id)
    res = await db.execute(
        select(WalletTransaction)
        .where(WalletTransaction.wallet_id == wallet.id)
        .order_by(desc(WalletTransaction.created_at))
        .limit(limit)
    )
    return list(res.scalars().all())


@router.post("/deposit", response_model=DepositResponse)
async def deposit(
    payload: DepositRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    wallet = await _get_or_create_wallet(db, user.id)
    reference = f"DEP-{uuid.uuid4().hex[:12].upper()}"
    wallet.balance_birr = float(wallet.balance_birr or 0) + float(payload.amount_birr)
    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="deposit",
            amount_birr=float(payload.amount_birr),
            amount_coins=0,
            description=f"{payload.provider} deposit",
            reference=reference,
        )
    )
    await maybe_grant(db, user, wallet)
    await db.commit()
    return DepositResponse(success=True, reference=reference, new_balance_birr=float(wallet.balance_birr))
