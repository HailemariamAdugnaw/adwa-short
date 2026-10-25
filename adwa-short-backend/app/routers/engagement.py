from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user
from app.models.content import Episode, Series
from app.models.engagement import Comment, Like, SavedItem, ViewLog
from app.models.subscription import Subscription, TimePassPurchase
from app.models.user import User

router = APIRouter(prefix="/engagement", tags=["engagement"])


class ViewRequest(BaseModel):
    episode_id: int
    watch_time_seconds: int = 0
    completed: bool = False


class LikeRequest(BaseModel):
    episode_id: int


class CommentRequest(BaseModel):
    episode_id: int
    body: str
    parent_id: Optional[int] = None


class SaveRequest(BaseModel):
    episode_id: int


class ViewOut(BaseModel):
    id: int
    episode_id: int
    watch_time_seconds: int
    completed: bool
    pass_purchase_id: Optional[int] = None
    subscription_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


class CommentOut(BaseModel):
    id: int
    user_id: int
    episode_id: int
    body: str
    parent_id: Optional[int]
    is_hidden: bool
    created_at: datetime

    class Config:
        from_attributes = True


async def _get_episode(db: AsyncSession, episode_id: int) -> Episode:
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    return ep


async def _find_active_pass(db: AsyncSession, user_id: int) -> Optional[TimePassPurchase]:
    now = datetime.now(timezone.utc)
    res = await db.execute(
        select(TimePassPurchase)
        .where(
            TimePassPurchase.user_id == user_id,
            TimePassPurchase.is_active.is_(True),
            TimePassPurchase.expires_at > now,
        )
        .order_by(TimePassPurchase.expires_at.desc())
        .limit(1)
    )
    return res.scalar_one_or_none()


async def _find_active_subscription(db: AsyncSession, user_id: int) -> Optional[Subscription]:
    now = datetime.now(timezone.utc)
    res = await db.execute(
        select(Subscription)
        .where(
            Subscription.user_id == user_id,
            Subscription.status == "active",
            Subscription.next_billing_at > now,
        )
        .order_by(Subscription.next_billing_at.desc())
        .limit(1)
    )
    return res.scalar_one_or_none()


@router.post("/view", response_model=ViewOut, status_code=status.HTTP_201_CREATED)
async def log_view(
    payload: ViewRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    ep = await _get_episode(db, payload.episode_id)
    pass_purchase = await _find_active_pass(db, user.id)
    subscription = await _find_active_subscription(db, user.id)
    v = ViewLog(
        user_id=user.id,
        episode_id=ep.id,
        series_id=ep.series_id,
        watch_time_seconds=payload.watch_time_seconds,
        completed=payload.completed,
        pass_purchase_id=pass_purchase.id if pass_purchase else None,
        subscription_id=subscription.id if subscription else None,
    )
    db.add(v)

    # 1. Valid View Qualification: View is officially qualified and performance view_count incremented
    # ONLY if watch_time_seconds >= 60 (1 minute threshold)
    if payload.watch_time_seconds >= 60:
        ep.view_count = (ep.view_count or 0) + 1
        if ep.series_id:
            sres = await db.execute(select(Series).where(Series.id == ep.series_id))
            series = sres.scalar_one_or_none()
            if series:
                series.view_count = (series.view_count or 0) + 1

        # 2. Coin Payment: If unlocked with coins and valid 1-minute threshold is met,
        # convert coin value to Birr, multiply by agreed creator split %, and credit immediately.
        from app.models.wallet import Wallet, WalletTransaction
        from app.models.revenue import RevenueTransaction
        from app.services.revenue import RevenueService
        from app.deps import get_settings_dict

        wtx_res = await db.execute(
            select(WalletTransaction)
            .join(Wallet, Wallet.id == WalletTransaction.wallet_id)
            .where(
                Wallet.user_id == user.id,
                WalletTransaction.type == "purchase",
                WalletTransaction.reference == f"episode:{ep.id}",
            )
        )
        coin_tx = wtx_res.scalar_one_or_none()
        if coin_tx is not None:
            rev_tx_res = await db.execute(
                select(RevenueTransaction).where(
                    RevenueTransaction.source_type == "coin_payment",
                    RevenueTransaction.episode_id == ep.id,
                    RevenueTransaction.user_id == user.id,
                )
            )
            if rev_tx_res.scalar_one_or_none() is None:
                coins_spent = abs(int(coin_tx.amount_coins)) if coin_tx.amount_coins else ep.coin_cost
                if coins_spent > 0:
                    sd = await get_settings_dict(db)
                    try:
                        coin_price = float(sd.get("coin_price_birr", "1.0"))
                    except (ValueError, TypeError):
                        coin_price = 1.0
                    rev_svc = RevenueService(db)
                    await rev_svc.calculate_coin_revenue(
                        episode_id=ep.id,
                        user_id=user.id,
                        coins_spent=coins_spent,
                        coin_price_birr=coin_price,
                    )

    await db.commit()
    await db.refresh(v)
    return v


@router.post("/like")
async def toggle_like(
    payload: LikeRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await _get_episode(db, payload.episode_id)
    res = await db.execute(
        select(Like).where(Like.user_id == user.id, Like.episode_id == payload.episode_id)
    )
    existing = res.scalar_one_or_none()
    if existing:
        await db.delete(existing)
        await db.commit()
        return {"liked": False}
    db.add(Like(user_id=user.id, episode_id=payload.episode_id))
    await db.commit()
    return {"liked": True}


@router.get("/likes/{episode_id}")
async def likes_count(episode_id: int, db: AsyncSession = Depends(get_db)):
    from sqlalchemy import func

    res = await db.execute(select(func.count(Like.id)).where(Like.episode_id == episode_id))
    return {"episode_id": episode_id, "likes": int(res.scalar_one())}


@router.post("/comment", response_model=CommentOut, status_code=status.HTTP_201_CREATED)
async def post_comment(
    payload: CommentRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await _get_episode(db, payload.episode_id)
    c = Comment(
        user_id=user.id,
        episode_id=payload.episode_id,
        parent_id=payload.parent_id,
        body=payload.body,
    )
    db.add(c)
    await db.commit()
    await db.refresh(c)
    return c


@router.get("/comments/{episode_id}", response_model=List[CommentOut])
async def list_comments(episode_id: int, db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(Comment)
        .where(Comment.episode_id == episode_id, Comment.is_hidden.is_(False))
        .order_by(Comment.created_at.desc())
    )
    return list(res.scalars().all())


@router.post("/save", status_code=status.HTTP_201_CREATED)
async def save_episode(
    payload: SaveRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    await _get_episode(db, payload.episode_id)
    res = await db.execute(
        select(SavedItem).where(SavedItem.user_id == user.id, SavedItem.episode_id == payload.episode_id)
    )
    if res.scalar_one_or_none() is not None:
        return {"saved": True, "detail": "Already saved"}
    db.add(SavedItem(user_id=user.id, episode_id=payload.episode_id))
    await db.commit()
    return {"saved": True}


@router.delete("/save/{episode_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unsave_episode(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(SavedItem).where(SavedItem.user_id == user.id, SavedItem.episode_id == episode_id)
    )
    s = res.scalar_one_or_none()
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not saved")
    await db.delete(s)
    await db.commit()


@router.get("/history")
async def history(
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(ViewLog, Episode, Series)
        .join(Episode, Episode.id == ViewLog.episode_id)
        .join(Series, Series.id == Episode.series_id, isouter=True)
        .where(ViewLog.user_id == user.id)
        .order_by(desc(ViewLog.created_at))
        .limit(limit)
    )
    out = []
    for v, ep, series in res.all():
        out.append(
            {
                "view_id": v.id,
                "episode_id": ep.id,
                "series_id": ep.series_id,
                "series_title": series.title if series else None,
                "episode_title": ep.title,
                "watch_time_seconds": v.watch_time_seconds,
                "completed": v.completed,
                "created_at": v.created_at.isoformat(),
            }
        )
    return out


@router.get("/saved")
async def saved_items(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(SavedItem, Episode, Series)
        .join(Episode, Episode.id == SavedItem.episode_id)
        .join(Series, Series.id == Episode.series_id, isouter=True)
        .where(SavedItem.user_id == user.id)
        .order_by(desc(SavedItem.created_at))
    )
    out = []
    for s, ep, series in res.all():
        out.append(
            {
                "saved_id": s.id,
                "episode_id": ep.id,
                "series_id": ep.series_id,
                "series_title": series.title if series else None,
                "episode_title": ep.title,
                "thumbnail_url": ep.thumbnail_url,
                "created_at": s.created_at.isoformat(),
            }
        )
    return out
