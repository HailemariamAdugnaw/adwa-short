from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreate(BaseModel):
    episode_id: int
    text: str = Field(min_length=1, max_length=2000)


class ReviewUpdate(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    episode_id: int
    series_id: Optional[int]
    text: str
    is_approved: bool
    created_at: datetime
    updated_at: datetime


class ReviewWithUserOut(BaseModel):
    id: int
    user_id: int
    episode_id: int
    series_id: Optional[int]
    text: str
    is_approved: bool
    created_at: datetime
    updated_at: datetime
    user_display_name: Optional[str] = None
    user_phone: Optional[str] = None
    user_avatar_url: Optional[str] = None


class ReviewListOut(BaseModel):
    items: List[ReviewWithUserOut]
    total: int
    page: int
    limit: int
