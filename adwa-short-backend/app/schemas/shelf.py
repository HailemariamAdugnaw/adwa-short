from __future__ import annotations

from typing import List

from pydantic import BaseModel, Field


class ShelfItemBrief(BaseModel):
    id: int
    title: str
    poster_url: str | None = None
    banner_url: str | None = None
    type: str = "series"
    is_vip: bool = False
    is_exclusive: bool = False
    episode_count: int = 0
    free_episode_count: int = 3
    popular_score: int = 0
    view_count: int = 0


class Shelf(BaseModel):
    key: str
    title: str
    type: str
    items: List[dict] = Field(default_factory=list)


class ShelfList(BaseModel):
    shelves: List[Shelf]
