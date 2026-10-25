from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class SplitRuleCreate(BaseModel):
    series_id: Optional[int] = None
    episode_id: Optional[int] = None
    creator_share_pct: float = Field(ge=0, le=100)


class SplitRuleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    creator_id: int
    series_id: Optional[int]
    episode_id: Optional[int]
    creator_share_pct: float
    is_active: bool
    created_at: datetime


class CreatorBase(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    legal_contract_url: Optional[str] = None
    contract_signed_date: Optional[datetime] = None
    bank_account_name: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_name: Optional[str] = None
    payment_method: Optional[str] = None
    mobile_money_number: Optional[str] = None
    tax_id: Optional[str] = None
    default_revenue_split_pct: float = Field(default=50.0, ge=0, le=100)
    is_active: bool = True


class CreatorCreate(CreatorBase):
    password: Optional[str] = None


class CreatorUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    legal_contract_url: Optional[str] = None
    contract_signed_date: Optional[datetime] = None
    bank_account_name: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_name: Optional[str] = None
    payment_method: Optional[str] = None
    mobile_money_number: Optional[str] = None
    tax_id: Optional[str] = None
    default_revenue_split_pct: Optional[float] = Field(default=None, ge=0, le=100)
    is_active: Optional[bool] = None


class CreatorOut(CreatorBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime


class CreatorListRow(CreatorOut):
    total_views: int = 0
    gross_revenue: float = 0.0
    creator_net: float = 0.0
    pending_balance: float = 0.0
    content_count: int = 0
    last_payout_date: Optional[datetime] = None


class CreatorDetailOut(CreatorOut):
    pending_balance_birr: float = 0.0
    lifetime_gross_birr: float = 0.0
    lifetime_creator_share_birr: float = 0.0
    lifetime_paid_out_birr: float = 0.0
    split_rules: List[SplitRuleOut] = Field(default_factory=list)


class RevenueTransactionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    creator_id: Optional[int]
    creator_display_name: Optional[str] = None
    creator_name: Optional[str] = None
    series_id: Optional[int]
    episode_id: Optional[int]
    user_id: Optional[int]
    source_type: str
    gross_amount_birr: float
    creator_share_birr: float
    platform_share_birr: float
    reference: Optional[str]
    created_at: datetime


class PayoutCreate(BaseModel):
    amount_birr: float = Field(gt=0)
    notes: Optional[str] = None


class PayoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    creator_id: int
    amount_birr: float
    status: str
    processed_at: Optional[datetime] = None
    processed_by_admin_id: Optional[int] = None
    notes: Optional[str] = None
    reference: Optional[str] = None
    created_at: datetime


class CreatorRevenueSummary(BaseModel):
    creator_id: int
    gross_amount_birr: float
    platform_share_birr: float
    creator_net_birr: float
    paid_out_birr: float
    pending_balance_birr: float
    total_views: int = 0
    by_month: List[dict] = Field(default_factory=list)


class CreatorContentItem(BaseModel):
    series_id: Optional[int] = None
    episode_id: Optional[int] = None
    title: str
    series_title: Optional[str] = None
    episode_number: Optional[int] = None
    is_series: bool
    episodes_count: int = 0
    total_views: int = 0
    coin_views: int = 0
    pass_views: int = 0
    subscription_views: int = 0
    ad_views: int = 0
    view_count: int = 0
    revenue_coins_birr: float = 0.0
    revenue_pass_birr: float = 0.0
    revenue_sub_birr: float = 0.0
    total_revenue_birr: float = 0.0


class RevenueOverview(BaseModel):
    total_gross_birr: float
    total_platform_share_birr: float
    total_creator_share_birr: float
    total_paid_out_birr: float
    total_pending_balance_birr: float
    transaction_count: int


class RevenueByCreatorRow(BaseModel):
    creator_id: Optional[int]
    creator_name: Optional[str]
    gross_birr: float
    creator_share_birr: float
    platform_share_birr: float
    pending_balance_birr: float


class RevenueByContentRow(BaseModel):
    series_id: Optional[int] = None
    episode_id: Optional[int] = None
    creator_id: Optional[int] = None
    creator_name: Optional[str] = None
    series_title: Optional[str] = None
    title: str
    content_type: str = "series"
    gross_birr: float = 0.0
    creator_share_birr: float = 0.0
    platform_share_birr: float = 0.0


class RevenueByMethodRow(BaseModel):
    source_type: str
    gross_birr: float
    creator_share_birr: float
    platform_share_birr: float
    transaction_count: int


class ProcessExpiredResult(BaseModel):
    processed_passes: int
    processed_subscriptions: int
    transactions_created: int
