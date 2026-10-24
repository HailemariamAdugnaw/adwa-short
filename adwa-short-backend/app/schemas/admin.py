from __future__ import annotations

from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class AuditLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    admin_id: Optional[int]
    action: str
    entity_type: str
    entity_id: Optional[int]
    details: Optional[str]
    created_at: datetime


class AdUnlockRuleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    ads_required: int
    episodes_unlocked: int
    is_active: bool
    updated_at: datetime


class AdUnlockRuleUpdate(BaseModel):
    ads_required: Optional[int] = None
    episodes_unlocked: Optional[int] = None
    is_active: Optional[bool] = None


class AdUnlockLogCreate(BaseModel):
    episode_id: int
    ads_watched: int = Field(ge=1)


class AdUnlockLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    episode_id: int
    ads_watched: int
    unlocked_at: datetime


class AnalyticsOverview(BaseModel):
    total_users: int
    total_series: int
    total_episodes: int
    total_shorts: int
    total_views_24h: int
    total_likes: int
    total_comments: int
    total_ratings: int
    total_reviews: int
    total_birr_deposited: float
    total_coins_spent: int
    active_subscriptions: int
    active_passes: int


class ContentRow(BaseModel):
    series_id: int
    title: str
    views: int
    likes: int
    comments: int
    popular_score: int
    watch_hours: float
    completion_rate: float


class RevenueRow(BaseModel):
    bucket: str
    birr: float
    coins: int


class RetentionRow(BaseModel):
    cohort: str
    d1: float
    d7: float
    d30: float


class AnalyticsContent(BaseModel):
    top_content: List[ContentRow]


class AnalyticsRevenue(BaseModel):
    rows: List[RevenueRow]


class AnalyticsRetention(BaseModel):
    rows: List[RetentionRow]


class UploadResponse(BaseModel):
    url: str
    filename: str
    size_bytes: int
