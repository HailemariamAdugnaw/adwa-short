from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AdUnlockRule(Base):
    __tablename__ = "ad_unlock_rules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ads_required: Mapped[int] = mapped_column(Integer, default=2, nullable=False)
    episodes_unlocked: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)


class AdUnlockLog(Base):
    __tablename__ = "ad_unlock_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    episode_id: Mapped[int] = mapped_column(ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False, index=True)
    ads_watched: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
