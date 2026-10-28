from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class CoinPackageBase(BaseModel):
    name: str
    coins: int
    price_birr: float
    episodes_unlocked: int = 0
    is_active: bool = True
    sort_order: int = 0


class CoinPackageCreate(CoinPackageBase):
    pass


class CoinPackageUpdate(BaseModel):
    name: Optional[str] = None
    coins: Optional[int] = None
    price_birr: Optional[float] = None
    episodes_unlocked: Optional[int] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class CoinPackageOut(CoinPackageBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class DepositRequest(BaseModel):
    amount_birr: float = Field(gt=0)
    provider: str = "cbe"
    phone: Optional[str] = None


class DepositResponse(BaseModel):
    success: bool
    reference: str
    new_balance_birr: float


class CoinPurchaseRequest(BaseModel):
    package_id: int


class CoinSpendRequest(BaseModel):
    episode_id: int


class CoinSpendResponse(BaseModel):
    success: bool
    new_balance_coins: int
    episode_id: int


class ManualDepositRequest(BaseModel):
    user_id: int
    amount_birr: Optional[float] = Field(default=0.0, ge=0.0)
    coins_credited: Optional[int] = Field(default=0, ge=0)
    notes: Optional[str] = None


TopUpRequest = ManualDepositRequest


class ManualDepositOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    admin_id: Optional[int]
    amount_birr: float
    coins_credited: int
    notes: Optional[str]
    created_at: datetime
    user_display_name: Optional[str] = None
    user_phone: Optional[str] = None


TopUpResponse = ManualDepositOut
