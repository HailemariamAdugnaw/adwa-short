from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.user import AdminUserAdjust, UserOut

router = APIRouter(prefix="/admin/users", tags=["admin-users"])


@router.get("", response_model=List[UserOut])
async def list_users(
    q: str | None = Query(default=None),
    status: str | None = Query(default=None, pattern="^(all|active|banned)$"),
    page: int | None = Query(default=None, ge=1),
    limit: int = Query(default=50, le=200),
    offset: int | None = Query(default=None, ge=0),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    stmt = select(User).where(User.role == "user")
    if status == "active":
        stmt = stmt.where(User.is_banned.is_(False))
    elif status == "banned":
        stmt = stmt.where(User.is_banned.is_(True))
    if q:
        pat = f"%{q}%"
        stmt = stmt.where(or_(User.phone.ilike(pat), User.email.ilike(pat), User.display_name.ilike(pat)))
    stmt = stmt.order_by(User.created_at.desc())
    if page is not None and offset is None:
        stmt = stmt.limit(limit).offset((page - 1) * limit)
    elif offset is not None:
        stmt = stmt.limit(limit).offset(offset)
    else:
        stmt = stmt.limit(limit)
    res = await db.execute(stmt)
    return list(res.scalars().all())


@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    res = await db.execute(select(User).where(User.id == user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return u


@router.put("/{user_id}/adjust", response_model=UserOut)
async def adjust_user(
    user_id: int,
    payload: AdminUserAdjust,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(User).where(User.id == user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if payload.is_banned is not None:
        u.is_banned = payload.is_banned
    if payload.is_active is not None:
        u.is_active = payload.is_active
    if payload.role is not None:
        u.role = payload.role
    if payload.balance_birr is not None or payload.balance_coins is not None:
        wres = await db.execute(select(Wallet).where(Wallet.user_id == u.id))
        wallet = wres.scalar_one_or_none()
        if wallet is None:
            wallet = Wallet(user_id=u.id, balance_birr=0, balance_coins=0)
            db.add(wallet)
        if payload.balance_birr is not None:
            wallet.balance_birr = payload.balance_birr
        if payload.balance_coins is not None:
            wallet.balance_coins = payload.balance_coins
    await db.commit()
    await db.refresh(u)
    return u


@router.post("/{user_id}/ban", response_model=UserOut)
async def ban_user(user_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    res = await db.execute(select(User).where(User.id == user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    u.is_banned = True
    await db.commit()
    await db.refresh(u)
    return u


@router.post("/{user_id}/unban", response_model=UserOut)
async def unban_user(user_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    res = await db.execute(select(User).where(User.id == user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    u.is_banned = False
    await db.commit()
    await db.refresh(u)
    return u
