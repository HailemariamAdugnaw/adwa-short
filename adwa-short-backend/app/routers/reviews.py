from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.content import Episode
from app.models.review import Review
from app.models.user import User
from app.schemas.review import ReviewCreate, ReviewListOut, ReviewOut, ReviewUpdate, ReviewWithUserOut

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.post("", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_review(
    payload: ReviewCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    review = Review(
        user_id=user.id,
        episode_id=payload.episode_id,
        series_id=ep.series_id,
        text=payload.text,
        is_approved=True,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)
    return review


@router.get("/episode/{episode_id}", response_model=ReviewListOut)
async def list_episode_reviews(
    episode_id: int,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, le=100),
    db: AsyncSession = Depends(get_db),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    if res.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    total_res = await db.execute(
        select(func.count(Review.id)).where(Review.episode_id == episode_id)
    )
    total = int(total_res.scalar_one() or 0)

    res = await db.execute(
        select(Review, User)
        .join(User, User.id == Review.user_id, isouter=True)
        .where(Review.episode_id == episode_id)
        .order_by(desc(Review.created_at))
        .limit(limit)
        .offset((page - 1) * limit)
    )
    items: List[ReviewWithUserOut] = []
    for r, u in res.all():
        items.append(_to_review_with_user(r, u))
    return ReviewListOut(items=items, total=total, page=page, limit=limit)


@router.put("/{review_id}", response_model=ReviewOut)
async def update_review(
    review_id: int,
    payload: ReviewUpdate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Review).where(Review.id == review_id))
    review = res.scalar_one_or_none()
    if review is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Review not found")
    if review.user_id != user.id and user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to edit this review")

    review.text = payload.text
    await db.commit()
    await db.refresh(review)
    return review


@router.delete("/{review_id}", status_code=status.HTTP_200_OK)
async def delete_review(
    review_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Review).where(Review.id == review_id))
    review = res.scalar_one_or_none()
    if review is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Review not found")
    if review.user_id != user.id and user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed to delete this review")
    await db.delete(review)
    await db.commit()
    return {"deleted": True, "id": review_id}


@router.get("/admin", response_model=ReviewListOut, tags=["admin-reviews"])
async def admin_list_reviews(
    episode_id: Optional[int] = None,
    user_id: Optional[int] = None,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    stmt = select(Review, User).join(User, User.id == Review.user_id, isouter=True)
    count_stmt = select(func.count(Review.id))
    if episode_id is not None:
        stmt = stmt.where(Review.episode_id == episode_id)
        count_stmt = count_stmt.where(Review.episode_id == episode_id)
    if user_id is not None:
        stmt = stmt.where(Review.user_id == user_id)
        count_stmt = count_stmt.where(Review.user_id == user_id)

    total = int((await db.execute(count_stmt)).scalar_one() or 0)

    stmt = stmt.order_by(desc(Review.created_at)).limit(limit).offset((page - 1) * limit)
    res = await db.execute(stmt)
    items: List[ReviewWithUserOut] = []
    for r, u in res.all():
        items.append(_to_review_with_user(r, u))
    return ReviewListOut(items=items, total=total, page=page, limit=limit)


@router.delete("/admin/{review_id}", status_code=status.HTTP_200_OK, tags=["admin-reviews"])
async def admin_delete_review(
    review_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(Review).where(Review.id == review_id))
    review = res.scalar_one_or_none()
    if review is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Review not found")
    await db.delete(review)
    await db.commit()
    return {"deleted": True, "id": review_id}


def _to_review_with_user(r: Review, u: Optional[User]) -> ReviewWithUserOut:
    return ReviewWithUserOut(
        id=r.id,
        user_id=r.user_id,
        episode_id=r.episode_id,
        series_id=r.series_id,
        text=r.text,
        is_approved=r.is_approved,
        created_at=r.created_at,
        updated_at=r.updated_at,
        user_display_name=u.display_name if u else None,
        user_phone=u.phone if u else None,
        user_avatar_url=u.avatar_url if u else None,
    )
