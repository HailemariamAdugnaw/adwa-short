from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.schema import UniqueConstraint

from app.database import Base
from app.utils.time import utcnow


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    icon_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    poster_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    series: Mapped[List["Series"]] = relationship(back_populates="category")


class Series(Base):
    __tablename__ = "series"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    poster_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    banner_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    category_id: Mapped[Optional[int]] = mapped_column(ForeignKey("categories.id", ondelete="SET NULL"), nullable=True, index=True)
    creator_id: Mapped[Optional[int]] = mapped_column(ForeignKey("creators.id", ondelete="SET NULL"), nullable=True, index=True)

    type: Mapped[str] = mapped_column(String(16), default="series", nullable=False)
    is_vip: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_exclusive: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)

    free_episode_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, default=None)
    coin_cost: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, default=None)
    total_episodes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    director: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    cast: Mapped[Optional[list]] = mapped_column(JSON, default=list, nullable=True)
    tags: Mapped[Optional[list]] = mapped_column(JSON, default=list, nullable=True)

    intro_bumper_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    is_hot: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_new_release: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_most_seen: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_frequent_seen: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_trending: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_popular: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_most_searched: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_most_viral: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    popular_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    view_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    viral_external_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)

    category: Mapped[Optional["Category"]] = relationship(back_populates="series")
    episodes: Mapped[List["Episode"]] = relationship(
        back_populates="series", cascade="all, delete-orphan", order_by="Episode.episode_number"
    )


class Episode(Base):
    __tablename__ = "episodes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    series_id: Mapped[int] = mapped_column(ForeignKey("series.id", ondelete="CASCADE"), nullable=False, index=True)
    creator_id: Mapped[Optional[int]] = mapped_column(ForeignKey("creators.id", ondelete="SET NULL"), nullable=True, index=True)
    episode_number: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    video_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    vertical_video_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    thumbnail_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    is_short: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    coin_cost: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    published_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    series: Mapped["Series"] = relationship(back_populates="episodes")

    __table_args__ = (UniqueConstraint("series_id", "episode_number", name="uq_series_episode_number"),)


class ShelfItem(Base):
    __tablename__ = "shelf_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    shelf_key: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    series_id: Mapped[Optional[int]] = mapped_column(ForeignKey("series.id", ondelete="CASCADE"), nullable=True)
    episode_id: Mapped[Optional[int]] = mapped_column(ForeignKey("episodes.id", ondelete="CASCADE"), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
