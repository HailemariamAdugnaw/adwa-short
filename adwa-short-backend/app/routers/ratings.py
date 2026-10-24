from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user
from app.models.content import Episode
from app.models.rating import Rating
from app.models.user import User
from app.schemas.rating import RatingAggregate, RatingCreate, RatingOut

router = APIRouter(prefix="/ratings", tags=["ratings"])


@router.post("", response_model=RatingOut)
async def create_or_update_rating(
    payload: RatingCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    rres = await db.execute(
        select(Rating).where(Rating.user_id == user.id, Rating.episode_id == payload.episode_id)
    )
    rating = rres.scalar_one_or_none()
    if rating is None:
        rating = Rating(
            user_id=user.id,
            episode_id=payload.episode_id,
            series_id=ep.series_id,
            rating=payload.rating,
        )
        db.add(rating)
    else:
        rating.rating = payload.rating
    await db.commit()
    await db.refresh(rating)
    return rating


@router.get("/episode/{episode_id}", response_model=RatingAggregate)
async def episode_rating_aggregate(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
):
    res = await db.execute(select(Episode).where(Episode.id == episode_id))
    if res.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")

    avg_res = await db.execute(
        select(func.avg(Rating.rating), func.count(Rating.id)).where(Rating.episode_id == episode_id)
    )
    avg, count = avg_res.one()
    count_int = int(count or 0)
    avg_float = float(avg) if count_int > 0 else 0.0

    dist_res = await db.execute(
        select(Rating.rating, func.count(Rating.id))
        .where(Rating.episode_id == episode_id)
        .group_by(Rating.rating)
    )
    distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    for star, cnt in dist_res.all():
        distribution[int(star)] = int(cnt or 0)

    return RatingAggregate(
        episode_id=episode_id,
        average=round(avg_float, 2),
        count=count_int,
        distribution=distribution,
    )


@router.delete("/{episode_id}", status_code=status.HTTP_200_OK)
async def delete_my_rating(
    episode_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(Rating).where(Rating.user_id == user.id, Rating.episode_id == episode_id)
    )
    rating = res.scalar_one_or_none()
    if rating is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rating not found")
    await db.delete(rating)
    await db.commit()
    return {"deleted": True, "episode_id": episode_id}


@router.get("/my", response_model=List[RatingOut])
async def my_ratings(
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(
        select(Rating)
        .where(Rating.user_id == user.id)
        .order_by(desc(Rating.updated_at))
        .limit(limit)
        .offset(offset)
    )
    return list(res.scalars().all())
