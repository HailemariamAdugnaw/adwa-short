from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_settings_dict
from app.models.content import Series


router = APIRouter(tags=["promotions"])


class PromotionalSplashOut(BaseModel):
    enabled: bool = True
    series_id: Optional[str] = None
    title: str
    poster_url: Optional[str] = None
    banner_url: Optional[str] = None
    countdown_seconds: int = 5
    action_text: str = "Watch Now"


def _to_bool(v: str, default: bool) -> bool:
    return str(v).strip().lower() in {"1", "true", "yes", "on"}


def _to_int(v: str, default: int) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


@router.get("/api/v1/promotions/splash", response_model=PromotionalSplashOut)
@router.get("/promotions/splash", response_model=PromotionalSplashOut)
@router.get("/api/v1/featured-poster", response_model=PromotionalSplashOut)
@router.get("/featured-poster", response_model=PromotionalSplashOut)
async def get_promotional_splash(
    db: AsyncSession = Depends(get_db),
):
    sd = await get_settings_dict(db)
    enabled = _to_bool(sd.get("intro_poster_enabled", "true"), True)
    countdown = _to_int(sd.get("intro_poster_countdown_seconds", "5"), 5)
    custom_series_id = _to_int(sd.get("intro_poster_series_id", "0"), 0) or None

    series = None
    if custom_series_id:
        sres = await db.execute(
            select(Series).where(Series.id == custom_series_id, Series.is_published.is_(True))
        )
        series = sres.scalar_one_or_none()

    if series is None:
        sres = await db.execute(
            select(Series)
            .where(Series.is_published.is_(True))
            .order_by(
                desc(Series.is_hot),
                desc(Series.is_new_release),
                desc(Series.popular_score),
                desc(Series.view_count),
                desc(Series.created_at),
            )
            .limit(1)
        )
        series = sres.scalar_one_or_none()

    if series is None:
        return PromotionalSplashOut(
            enabled=False,
            series_id=None,
            title="No Active Promotion",
            poster_url=None,
            banner_url=None,
            countdown_seconds=countdown,
            action_text="Watch Now",
        )

    high_res_poster = series.poster_url or series.banner_url
    is_active = enabled and bool(high_res_poster and high_res_poster.strip())

    return PromotionalSplashOut(
        enabled=is_active,
        series_id=str(series.id),
        title=series.title,
        poster_url=high_res_poster,
        banner_url=series.banner_url,
        countdown_seconds=countdown,
        action_text="Watch Now",
    )
