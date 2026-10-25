from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.deps import get_current_admin
from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.user import User
from app.models.wallet import Wallet, WalletTransaction
from app.schemas.user import AdminUserAdjust, UserDetailOut, UserOut, WalletDetailOut, WalletTxOut
from app.utils.time import utcnow

router = APIRouter(prefix="/admin/users", tags=["admin-users"])


@router.get("", response_model=List[UserOut])
async def list_users(
    q: str | None = Query(default=None),
    status: str | None = Query(default=None, pattern="^(all|active|banned)$"),
    role: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int = Query(default=50, le=200),
    offset: int | None = Query(default=None, ge=0),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    stmt = select(User).options(selectinload(User.wallet))
    if role:
        stmt = stmt.where(User.role == role)
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


@router.get("/{user_id}", response_model=UserDetailOut)
async def get_user(user_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    res = await db.execute(select(User).options(selectinload(User.wallet)).where(User.id == user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Fetch subscriptions
    sub_res = await db.execute(
        select(Subscription)
        .options(selectinload(Subscription.plan))
        .where(Subscription.user_id == user_id)
        .order_by(Subscription.created_at.desc())
    )
    subscriptions = []
    for s in sub_res.scalars().all():
        subscriptions.append({
            "id": s.id,
            "user_id": s.user_id,
            "plan_id": s.plan_id,
            "status": s.status,
            "started_at": s.started_at,
            "next_billing_at": s.next_billing_at,
            "created_at": s.created_at,
            "plan": {
                "id": s.plan.id,
                "name": s.plan.name,
                "price_birr": float(s.plan.price_birr),
                "billing_cycle": s.plan.billing_cycle,
            } if s.plan else None,
        })

    # Fetch passes
    now = utcnow()
    pass_res = await db.execute(
        select(TimePassPurchase)
        .options(selectinload(TimePassPurchase.pass_))
        .where(TimePassPurchase.user_id == user_id)
        .order_by(TimePassPurchase.created_at.desc())
    )
    passes = []
    for p in pass_res.scalars().all():
        is_act = bool(p.is_active and p.expires_at > now)
        passes.append({
            "id": p.id,
            "user_id": p.user_id,
            "pass_id": p.pass_id,
            "starts_at": p.starts_at,
            "expires_at": p.expires_at,
            "is_active": is_act,
            "created_at": p.created_at,
            "pass": {
                "id": p.pass_.id,
                "name": p.pass_.name,
                "duration_hours": p.pass_.duration_hours,
                "price_birr": float(p.pass_.price_birr),
            } if p.pass_ else None,
        })

    # Fetch watch history
    v_res = await db.execute(
        select(ViewLog, Episode, Series)
        .join(Episode, Episode.id == ViewLog.episode_id, isouter=True)
        .join(Series, Series.id == ViewLog.series_id, isouter=True)
        .where(ViewLog.user_id == user_id)
        .order_by(ViewLog.created_at.desc())
        .limit(30)
    )
    watch_history = []
    for log, ep, ser in v_res.all():
        duration = ep.duration_seconds if (ep and ep.duration_seconds and ep.duration_seconds > 0) else 1
        pct = min(100.0, (log.watch_time_seconds / duration) * 100.0) if (ep and ep.duration_seconds) else (100.0 if log.completed else 50.0)
        watch_history.append({
            "id": log.id,
            "episode_id": log.episode_id,
            "series_id": log.series_id,
            "series_title": ser.title if ser else None,
            "episode_number": ep.episode_number if ep else None,
            "episode_title": ep.title if ep else None,
            "watch_time_seconds": log.watch_time_seconds,
            "progress_percent": round(pct, 1),
            "watched_at": log.created_at,
        })

    return UserDetailOut(
        id=u.id,
        phone=u.phone,
        email=u.email,
        display_name=u.display_name,
        avatar_url=u.avatar_url,
        role=u.role,
        is_active=u.is_active,
        is_banned=u.is_banned,
        created_at=u.created_at,
        balance_birr=u.balance_birr,
        balance_coins=u.balance_coins,
        subscriptions=subscriptions,
        passes=passes,
        watch_history=watch_history,
    )


@router.get("/{user_id}/wallet", response_model=WalletDetailOut)
async def get_user_wallet(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(User).where(User.id == user_id))
    u = res.scalar_one_or_none()
    if u is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    wres = await db.execute(select(Wallet).where(Wallet.user_id == u.id))
    wallet = wres.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=u.id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.commit()
        await db.refresh(wallet)

    tx_res = await db.execute(
        select(WalletTransaction)
        .where(WalletTransaction.wallet_id == wallet.id)
        .order_by(WalletTransaction.created_at.desc())
        .limit(50)
    )
    txs = list(tx_res.scalars().all())

    return WalletDetailOut(
        id=wallet.id,
        user_id=wallet.user_id,
        balance_birr=float(wallet.balance_birr or 0),
        balance_coins=int(wallet.balance_coins or 0),
        updated_at=wallet.updated_at,
        transactions=[
            WalletTxOut(
                id=t.id,
                type=t.type,
                amount_birr=float(t.amount_birr or 0),
                amount_coins=int(t.amount_coins or 0),
                description=t.description,
                reference=t.reference,
                created_at=t.created_at,
            )
            for t in txs
        ],
    )


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
