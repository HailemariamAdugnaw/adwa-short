from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AdUnlockRule(Base):
    __tablename__ = "ad_unlock_rules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ads_required: Mapped[int] = mapped_column(Integer, default=2, nullable=False)
    episodes_unlocked: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    provider: Mapped[str] = mapped_column(String(32), default="admob", nullable=False)
    app_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    banner_unit_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    interstitial_unit_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    rewarded_unit_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    api_key: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    callback_secret: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    test_mode: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class AdUnlockLog(Base):
    __tablename__ = "ad_unlock_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    episode_id: Mapped[int] = mapped_column(ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False, index=True)
    ads_watched: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    revenue_birr: Mapped[float] = mapped_column(Numeric(10, 4), default=0.0, nullable=False)
    ad_network: Mapped[Optional[str]] = mapped_column(String(32), nullable=True, default="admob")
    verified_via: Mapped[str] = mapped_column(String(32), default="client", nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class AdImpressionLog(Base):
    __tablename__ = "ad_impression_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    episode_id: Mapped[Optional[int]] = mapped_column(ForeignKey("episodes.id", ondelete="SET NULL"), nullable=True, index=True)
    ad_unit_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    ad_network: Mapped[str] = mapped_column(String(32), default="admob", nullable=False)
    ad_type: Mapped[str] = mapped_column(String(32), default="rewarded", nullable=False)
    revenue_birr: Mapped[float] = mapped_column(Numeric(10, 4), default=0.0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
