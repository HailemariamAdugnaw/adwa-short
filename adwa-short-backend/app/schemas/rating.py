from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class RatingCreate(BaseModel):
    episode_id: int
    rating: int = Field(ge=1, le=5)


class RatingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    episode_id: int
    series_id: Optional[int]
    rating: int
    created_at: datetime
    updated_at: datetime


class RatingAggregate(BaseModel):
    episode_id: int
    average: float
    count: int
    distribution: dict[int, int]
