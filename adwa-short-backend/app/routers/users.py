from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.content import Episode, Series
from app.models.engagement import ViewLog
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.user import User
from app.schemas.user import UserDetailOut, UserOut, UserUpdate
from app.utils.time import utcnow
from sqlalchemy.orm import selectinload

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
async def get_me(user: User = Depends(get_current_user)):
    return user


@router.put("/me", response_model=UserOut)
async def update_me(
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if payload.display_name is not None:
        user.display_name = payload.display_name
    if payload.email is not None:
        user.email = payload.email
    if payload.avatar_url is not None:
        user.avatar_url = payload.avatar_url
    await db.commit()
    await db.refresh(user)
    return user


@router.get("/{user_id}", response_model=UserDetailOut)
async def get_user(user_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_admin)):
    res = await db.execute(select(User).options(selectinload(User.wallet)).where(User.id == user_id))
    user = res.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

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
        id=user.id,
        phone=user.phone,
        email=user.email,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        role=user.role,
        is_active=user.is_active,
        is_banned=user.is_banned,
        created_at=user.created_at,
        balance_birr=user.balance_birr,
        balance_coins=user.balance_coins,
        subscriptions=subscriptions,
        passes=passes,
        watch_history=watch_history,
    )
