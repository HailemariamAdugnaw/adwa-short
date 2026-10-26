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
    provider: str = "admob"
    app_id: Optional[str] = None
    banner_unit_id: Optional[str] = None
    interstitial_unit_id: Optional[str] = None
    rewarded_unit_id: Optional[str] = None
    api_key: Optional[str] = None
    callback_secret: Optional[str] = None
    test_mode: bool = True
    updated_at: datetime


class AdUnlockRuleUpdate(BaseModel):
    ads_required: Optional[int] = None
    episodes_unlocked: Optional[int] = None
    is_active: Optional[bool] = None
    provider: Optional[str] = None
    app_id: Optional[str] = None
    banner_unit_id: Optional[str] = None
    interstitial_unit_id: Optional[str] = None
    rewarded_unit_id: Optional[str] = None
    api_key: Optional[str] = None
    callback_secret: Optional[str] = None
    test_mode: Optional[bool] = None


class AdUnlockLogCreate(BaseModel):
    episode_id: int
    ads_watched: int = Field(default=2, ge=1)
    ad_network: Optional[str] = "admob"
    revenue_birr: Optional[float] = None
    payout: Optional[float] = None


class AdWebhookPostbackResponse(BaseModel):
    status: str
    message: str
    episode_id: Optional[int] = None
    user_id: Optional[int] = None
    ad_network: Optional[str] = None
    revenue_birr: Optional[float] = None
    revenue_credited_to_platform_birr: Optional[float] = None
    platform_share_birr: Optional[float] = None
    creator_share_birr: float = 0.0
    revenue_source: Optional[str] = None
    transaction_id: Optional[str] = None


class AdUnlockLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    episode_id: int
    ads_watched: int
    revenue_birr: float = 0.0
    ad_network: Optional[str] = None
    verified_via: str = "client"
    unlocked_at: datetime
    user_display_name: Optional[str] = None
    episode_title: Optional[str] = None
    series_title: Optional[str] = None


class AdImpressionCreate(BaseModel):
    episode_id: Optional[int] = None
    ad_unit_id: Optional[str] = None
    ad_network: str = "admob"
    ad_type: str = "rewarded"
    revenue_birr: Optional[float] = None


class AdImpressionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: Optional[int] = None
    episode_id: Optional[int] = None
    ad_unit_id: Optional[str] = None
    ad_network: str
    ad_type: str
    revenue_birr: float
    created_at: datetime


class AdRewardCallbackPayload(BaseModel):
    user_id: int
    episode_id: int
    secret: Optional[str] = None
    token: Optional[str] = None
    reward_amount: Optional[int] = None
    network: Optional[str] = "admob"


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
    views: int = 0
    qualified_views: int = 0
    total_raw_views: int = 0
    coin_views: int = 0
    pass_views: int = 0
    subscription_views: int = 0
    ad_views: int = 0
    free_views: int = 0
    total_watch_seconds: int = 0
    watch_hours: float = 0.0
    likes: int = 0
    comments: int = 0
    popular_score: int = 0
    completion_rate: float = 0.0


class EpisodeContentRow(BaseModel):
    episode_id: int
    series_id: int
    series_title: str
    episode_number: int
    title: str
    views: int = 0
    qualified_views: int = 0
    total_raw_views: int = 0
    coin_views: int = 0
    pass_views: int = 0
    subscription_views: int = 0
    ad_views: int = 0
    free_views: int = 0
    total_watch_seconds: int = 0
    watch_hours: float = 0.0
    likes: int = 0
    comments: int = 0
    completion_rate: float = 0.0


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
    episodes: Optional[List[EpisodeContentRow]] = None


class AnalyticsRevenue(BaseModel):
    rows: List[RevenueRow]


class AnalyticsRetention(BaseModel):
    rows: List[RetentionRow]


class UploadResponse(BaseModel):
    url: str
    filename: str
    size_bytes: int
