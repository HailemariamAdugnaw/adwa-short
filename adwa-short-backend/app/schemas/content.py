from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class CategoryBase(BaseModel):
    name: str
    description: Optional[str] = None
    icon_url: Optional[str] = None
    poster_url: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    icon_url: Optional[str] = None
    poster_url: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class CategoryOut(CategoryBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime


class EpisodeBase(BaseModel):
    episode_number: int
    title: str
    description: Optional[str] = None
    video_url: Optional[str] = None
    vertical_video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    duration_seconds: int = 0
    is_short: bool = False
    coin_cost: int = 0
    creator_id: Optional[int] = None


class EpisodeCreate(EpisodeBase):
    series_id: int


class EpisodeUpdate(BaseModel):
    episode_number: Optional[int] = None
    title: Optional[str] = None
    description: Optional[str] = None
    video_url: Optional[str] = None
    vertical_video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    duration_seconds: Optional[int] = None
    is_short: Optional[bool] = None
    coin_cost: Optional[int] = None
    creator_id: Optional[int] = None


class EpisodeOut(EpisodeBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    series_id: int
    is_published: bool
    published_at: Optional[datetime] = None
    view_count: int
    created_at: datetime


class SeriesBase(BaseModel):
    title: str
    description: Optional[str] = None
    poster_url: Optional[str] = None
    banner_url: Optional[str] = None
    category_id: Optional[int] = None
    creator_id: Optional[int] = None
    type: str = "series"
    is_vip: bool = False
    is_exclusive: bool = False
    is_published: bool = False
    free_episode_count: int = 3
    total_episodes: int = 0
    director: Optional[str] = None
    cast: List[str] = Field(default_factory=list)
    tags: List[str] = Field(default_factory=list)
    intro_bumper_url: Optional[str] = None


class SeriesCreate(SeriesBase):
    pass


class SeriesUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    poster_url: Optional[str] = None
    banner_url: Optional[str] = None
    category_id: Optional[int] = None
    creator_id: Optional[int] = None
    type: Optional[str] = None
    is_vip: Optional[bool] = None
    is_exclusive: Optional[bool] = None
    is_published: Optional[bool] = None
    free_episode_count: Optional[int] = None
    total_episodes: Optional[int] = None
    director: Optional[str] = None
    cast: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    intro_bumper_url: Optional[str] = None
    is_hot: Optional[bool] = None
    is_new_release: Optional[bool] = None
    is_most_seen: Optional[bool] = None
    is_frequent_seen: Optional[bool] = None
    is_trending: Optional[bool] = None
    is_popular: Optional[bool] = None
    is_most_searched: Optional[bool] = None
    is_most_viral: Optional[bool] = None


class SeriesOut(SeriesBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    is_hot: bool
    is_new_release: bool
    is_most_seen: bool
    is_frequent_seen: bool
    is_trending: bool
    is_popular: bool
    is_most_searched: bool
    is_most_viral: bool
    popular_score: int
    view_count: int
    viral_external_score: int
    created_at: datetime
    updated_at: datetime


class SeriesDetailOut(SeriesOut):
    episodes: List[EpisodeOut] = Field(default_factory=list)


class ShelfItemOut(BaseModel):
    id: int
    title: str
    poster_url: Optional[str] = None
    banner_url: Optional[str] = None
    type: str
    is_vip: bool
    is_exclusive: bool
    episode_count: int = 0
    free_episode_count: int = 3


class ShelfOut(BaseModel):
    key: str
    title: str
    type: str
    items: List[dict] = Field(default_factory=list)


class ShortsFeedItem(BaseModel):
    episode_id: int
    series_id: int
    title: str
    series_title: str
    description: Optional[str] = None
    vertical_video_url: Optional[str] = None
    video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    duration_seconds: int
    episode_number: int = 0
    total_episodes: int = 0
    view_count: int
    coin_cost: int
    is_short: bool = False
    is_accessible: bool = False
    access_reason: str = "need_subscription"
    creator_id: Optional[int] = None
