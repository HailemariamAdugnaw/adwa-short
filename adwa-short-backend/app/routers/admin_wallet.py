from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_super_admin
from app.models.admin import ManualCashDeposit
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction
from app.schemas.wallet import ManualDepositOut, ManualDepositRequest

router = APIRouter(prefix="/admin/wallet", tags=["admin-wallet"])


@router.post("/manual-deposit", response_model=ManualDepositOut, status_code=status.HTTP_201_CREATED)
async def manual_deposit(
    payload: ManualDepositRequest,
    db: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_super_admin),
):
    res = await db.execute(select(User).where(User.id == payload.user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    wres = await db.execute(select(Wallet).where(Wallet.user_id == u.id))
    wallet = wres.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=u.id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()

    wallet.balance_birr = float(wallet.balance_birr or 0) + float(payload.amount_birr)
    if payload.coins_credited:
        wallet.balance_coins = int(wallet.balance_coins or 0) + int(payload.coins_credited)

    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="admin",
            amount_birr=float(payload.amount_birr),
            amount_coins=int(payload.coins_credited or 0),
            description=payload.notes or "Manual cash deposit",
            reference=f"admin:{admin.id}",
        )
    )

    record = ManualCashDeposit(
        user_id=u.id,
        admin_id=admin.id,
        amount_birr=float(payload.amount_birr),
        coins_credited=int(payload.coins_credited or 0),
        notes=payload.notes,
    )
    db.add(record)

    from app.services.loyalty_engine import maybe_grant
    await maybe_grant(db, u, wallet)

    await db.commit()
    await db.refresh(record)
    return record


@router.get("/manual-deposits", response_model=List[ManualDepositOut])
async def list_manual_deposits(
    user_id: int | None = None,
    q: str | None = None,
    page: int | None = None,
    limit: int = 100,
    offset: int | None = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    stmt = select(ManualCashDeposit).order_by(desc(ManualCashDeposit.created_at))
    if user_id is not None:
        stmt = stmt.where(ManualCashDeposit.user_id == user_id)
    if q:
        joined = stmt.join(User, User.id == ManualCashDeposit.user_id)
        pat = f"%{q}%"
        stmt = joined.where(or_(User.phone.ilike(pat), User.display_name.ilike(pat)))
    if page is not None and offset is None:
        stmt = stmt.limit(limit).offset((page - 1) * limit)
    elif offset is not None:
        stmt = stmt.limit(limit).offset(offset)
    else:
        stmt = stmt.limit(limit)
    res = await db.execute(stmt)
    return list(res.scalars().all())
