from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    phone: str
    email: Optional[str]
    display_name: str
    avatar_url: Optional[str]
    role: str
    is_active: bool
    is_banned: bool = False
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None


class WalletOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    balance_birr: float
    balance_coins: int
    updated_at: datetime


class WalletTxOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str
    amount_birr: float
    amount_coins: int
    description: Optional[str]
    reference: Optional[str]
    created_at: datetime


class DeviceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_fingerprint: str
    device_name: Optional[str]
    platform: str
    last_seen: datetime
    is_active: bool
    created_at: datetime


class DeviceRegister(BaseModel):
    device_fingerprint: str
    device_name: Optional[str] = None
    platform: str = "android"


class AdminUserAdjust(BaseModel):
    balance_birr: Optional[float] = None
    balance_coins: Optional[int] = None
    is_banned: Optional[bool] = None
    is_active: Optional[bool] = None
    role: Optional[str] = None
