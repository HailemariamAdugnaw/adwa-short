from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class SettingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    key: str
    value: str
    description: str
    updated_at: datetime


class SettingUpdate(BaseModel):
    value: str
    description: Optional[str] = None


class PublicSettings(BaseModel):
    maintenance_mode: bool
    free_trial_default_episodes: int
    max_devices_per_account: int
    coin_price_birr: float
    ad_unlock_ads_required: int
    ad_unlock_episodes_unlocked: int
