from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict


class LoyaltyConfigOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    min_balance_birr: float
    max_balance_birr: float
    daily_access_days: int
    free_coins: int
    free_full_series_count: int
    is_active: bool
    updated_at: datetime


class LoyaltyConfigUpdate(BaseModel):
    min_balance_birr: Optional[float] = None
    max_balance_birr: Optional[float] = None
    daily_access_days: Optional[int] = None
    free_coins: Optional[int] = None
    free_full_series_count: Optional[int] = None
    is_active: Optional[bool] = None


class LoyaltyGrantOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    reward_id: Optional[int] = None
    details: Optional[Any]
    granted_at: datetime


class LoyaltyStatusOut(BaseModel):
    min_balance_birr: float
    max_balance_birr: float
    daily_access_days: int
    free_coins: int
    free_full_series_count: int
    is_active: bool
    wallet_balance_birr: float
    wallet_balance_coins: int
    qualifies: bool
    needed_birr: float
    progress_pct: float
    can_claim: bool
    reward_id: Optional[int] = None
    is_claimed: bool = False


class LoyaltyClaimOut(BaseModel):
    status: str
    message: str
    coins_awarded: int
    days_access_awarded: int
    free_series_awarded: int
    new_balance_coins: int
    reward_id: Optional[int] = None
    is_claimed: bool = True
