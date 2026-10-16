from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, Numeric, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LoyaltyRewardConfig(Base):
    __tablename__ = "loyalty_reward_configs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    min_balance_birr: Mapped[float] = mapped_column(Numeric(12, 2), default=3500, nullable=False)
    max_balance_birr: Mapped[float] = mapped_column(Numeric(12, 2), default=5000, nullable=False)
    daily_access_days: Mapped[int] = mapped_column(Integer, default=7, nullable=False)
    free_coins: Mapped[int] = mapped_column(Integer, default=1000, nullable=False)
    free_full_series_count: Mapped[int] = mapped_column(Integer, default=2, nullable=False)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class LoyaltyRewardGrant(Base):
    __tablename__ = "loyalty_reward_grants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    granted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
