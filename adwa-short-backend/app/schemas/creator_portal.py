from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.revenue import PayoutOut, SplitRuleOut


class CreatorSummaryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    default_revenue_split_pct: float


class EarningsSummaryOut(BaseModel):
    gross_revenue_birr: float = 0.0
    platform_commission_birr: float = 0.0
    creator_net_birr: float = 0.0
    pending_balance_birr: float = 0.0
    paid_out_birr: float = 0.0


class PerformanceMetricsOut(BaseModel):
    qualified_views: int = 0
    watch_time_seconds: int = 0
    watch_time_hours: float = 0.0
    series_count: int = 0
    episodes_count: int = 0


class CreatorDashboardOut(BaseModel):
    creator: CreatorSummaryOut
    earnings: EarningsSummaryOut
    metrics: PerformanceMetricsOut
    pending_balance_birr: float = 0.0
    recent_payouts: List[PayoutOut] = Field(default_factory=list)
    monthly_trend: List[Dict[str, Any]] = Field(default_factory=list)


class CreatorContentBreakdownItem(BaseModel):
    id: int
    series_id: int
    episode_id: Optional[int] = None
    title: str
    series_title: str
    episode_number: Optional[int] = None
    is_series: bool = False
    episodes_count: int = 1
    coin_views: int = 0
    pass_views: int = 0
    subscription_views: int = 0
    ad_views: int = 0
    total_views: int = 0
    revenue_coins_birr: float = 0.0
    revenue_pass_birr: float = 0.0
    revenue_sub_birr: float = 0.0
    revenue_ad_birr: float = 0.0
    total_revenue_birr: float = 0.0
    average_rating: float = 0.0
    rating_count: int = 0


class CreatorReviewItem(BaseModel):
    id: int
    user_display_name: str
    series_title: str
    episode_title: str
    episode_number: int
    text: str
    rating: Optional[int] = None
    created_at: datetime


class CreatorReviewsResponse(BaseModel):
    average_rating: float = 0.0
    total_ratings: int = 0
    total_reviews: int = 0
    items: List[CreatorReviewItem] = Field(default_factory=list)


class CreatorPayoutAccountIn(BaseModel):
    bank_name: Optional[str] = None
    bank_account_name: Optional[str] = None
    bank_account_number: Optional[str] = None
    payment_method: Optional[str] = None
    mobile_money_number: Optional[str] = None
    tax_id: Optional[str] = None


class CreatorPayoutAccountOut(BaseModel):
    bank_name: Optional[str] = None
    bank_account_name: Optional[str] = None
    bank_account_number: Optional[str] = None
    payment_method: Optional[str] = None
    mobile_money_number: Optional[str] = None
    tax_id: Optional[str] = None


class CreatorTransactionItem(BaseModel):
    id: int
    source_type: str
    gross_amount_birr: float = 0.0
    creator_share_birr: float = 0.0
    platform_share_birr: float = 0.0
    reference: Optional[str] = None
    series_title: Optional[str] = None
    episode_title: Optional[str] = None
    created_at: datetime


class CreatorProfileUpdateIn(BaseModel):
    display_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    phone: Optional[str] = None


class CreatorProfileOut(BaseModel):
    id: int
    name: str
    display_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    created_at: datetime
    default_revenue_split_pct: float
    legal_contract_url: Optional[str] = None
    contract_signed_date: Optional[datetime] = None
    split_rules: List[SplitRuleOut] = Field(default_factory=list)
