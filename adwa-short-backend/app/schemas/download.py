from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class DownloadRequest(BaseModel):
    episode_id: int


class DownloadTokenResponse(BaseModel):
    token: str
    download_url: str
    expires_at: datetime
    episode_id: int
    episode_title: str
    series_title: Optional[str] = None
    duration_seconds: int = 0


class DownloadedEpisodeInfo(BaseModel):
    episode_id: int
    episode_title: str
    series_id: int
    series_title: Optional[str] = None
    episode_number: int = 0
    duration_seconds: int = 0
    thumbnail_url: Optional[str] = None
    downloaded_at: Optional[datetime] = None


class DownloadTokenListResponse(BaseModel):
    tokens: list[DownloadedEpisodeInfo]
    total: int
