from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.utils.time import utcnow


class Creator(Base):
    __tablename__ = "creators"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    phone: Mapped[Optional[str]] = mapped_column(String(32), nullable=True, index=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    legal_contract_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    contract_signed_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    bank_account_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    bank_account_number: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    bank_name: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    payment_method: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)

    default_revenue_split_pct: Mapped[float] = mapped_column(Numeric(5, 2), default=50.0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)

    split_rules: Mapped[list["RevenueSplitRule"]] = relationship(
        back_populates="creator", cascade="all, delete-orphan"
    )
    transactions: Mapped[list["RevenueTransaction"]] = relationship(
        back_populates="creator", cascade="all, delete-orphan"
    )
    payouts: Mapped[list["Payout"]] = relationship(
        back_populates="creator", cascade="all, delete-orphan"
    )


class RevenueSplitRule(Base):
    __tablename__ = "revenue_split_rules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    creator_id: Mapped[int] = mapped_column(ForeignKey("creators.id", ondelete="CASCADE"), nullable=False, index=True)
    series_id: Mapped[Optional[int]] = mapped_column(ForeignKey("series.id", ondelete="CASCADE"), nullable=True, index=True)
    episode_id: Mapped[Optional[int]] = mapped_column(ForeignKey("episodes.id", ondelete="CASCADE"), nullable=True, index=True)
    creator_share_pct: Mapped[float] = mapped_column(Numeric(5, 2), default=50.0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    creator: Mapped["Creator"] = relationship(back_populates="split_rules")


class RevenueTransaction(Base):
    __tablename__ = "revenue_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    creator_id: Mapped[Optional[int]] = mapped_column(ForeignKey("creators.id", ondelete="SET NULL"), nullable=True, index=True)
    series_id: Mapped[Optional[int]] = mapped_column(ForeignKey("series.id", ondelete="SET NULL"), nullable=True, index=True)
    episode_id: Mapped[Optional[int]] = mapped_column(ForeignKey("episodes.id", ondelete="SET NULL"), nullable=True, index=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)

    source_type: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    gross_amount_birr: Mapped[float] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    creator_share_birr: Mapped[float] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    platform_share_birr: Mapped[float] = mapped_column(Numeric(12, 2), default=0, nullable=False)
    reference: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    payout_id: Mapped[Optional[int]] = mapped_column(ForeignKey("payouts.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    creator: Mapped[Optional["Creator"]] = relationship(back_populates="transactions", lazy="selectin")

    @property
    def creator_display_name(self) -> Optional[str]:
        if self.creator:
            return self.creator.display_name or self.creator.name
        return None

    @property
    def creator_name(self) -> Optional[str]:
        return self.creator.name if self.creator else None


class Payout(Base):
    __tablename__ = "payouts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    creator_id: Mapped[int] = mapped_column(ForeignKey("creators.id", ondelete="CASCADE"), nullable=False, index=True)
    amount_birr: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="pending", nullable=False, index=True)
    processed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    processed_by_admin_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    reference: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    creator: Mapped["Creator"] = relationship(back_populates="payouts")
