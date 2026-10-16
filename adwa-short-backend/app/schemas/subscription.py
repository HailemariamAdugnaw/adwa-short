from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TimePassBase(BaseModel):
    name: str
    duration_hours: int
    price_birr: float
    is_active: bool = True
    sort_order: int = 0


class TimePassCreate(TimePassBase):
    pass


class TimePassUpdate(BaseModel):
    name: Optional[str] = None
    duration_hours: Optional[int] = None
    price_birr: Optional[float] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class TimePassOut(TimePassBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class TimePassPurchaseRequest(BaseModel):
    pass_id: int


class TimePassPurchaseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    pass_id: int
    starts_at: datetime
    expires_at: datetime
    is_active: bool
    created_at: datetime


class SubscriptionPlanBase(BaseModel):
    name: str
    billing_cycle: str
    price_birr: float
    is_active: bool = True


class SubscriptionPlanCreate(SubscriptionPlanBase):
    pass


class SubscriptionPlanUpdate(BaseModel):
    name: Optional[str] = None
    billing_cycle: Optional[str] = None
    price_birr: Optional[float] = None
    is_active: Optional[bool] = None


class SubscriptionPlanOut(SubscriptionPlanBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class SubscribeRequest(BaseModel):
    plan_id: int


class SubscriptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    plan_id: int
    status: str
    started_at: datetime
    next_billing_at: datetime
    canceled_at: Optional[datetime]
    created_at: datetime


class AccessStatus(BaseModel):
    has_active_pass: bool
    pass_expires_at: Optional[datetime] = None
    has_active_subscription: bool
    subscription_expires_at: Optional[datetime] = None
    balance_birr: float
    balance_coins: int
