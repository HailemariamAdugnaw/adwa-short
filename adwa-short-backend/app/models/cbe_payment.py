from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.utils.time import utcnow


class CbePaymentOrder(Base):
    """Tracks automated Commercial Bank of Ethiopia (CBE / CBE Birr) payment transactions."""
    __tablename__ = "cbe_payment_orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    order_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    item_type: Mapped[str] = mapped_column(String(32), nullable=False)  # 'coins', 'time_pass', 'subscription', 'wallet_deposit'
    item_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # package_id, pass_id, plan_id
    amount_birr: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="ETB", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="pending", nullable=False, index=True)  # pending, completed, failed, canceled

    # CBE Gateway references
    cbe_transaction_id: Mapped[Optional[str]] = mapped_column(String(128), unique=True, nullable=True, index=True)
    bill_reference: Mapped[Optional[str]] = mapped_column(String(64), nullable=True, index=True)
    checkout_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    ussd_code: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    payer_phone: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    payer_account: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    signature: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    webhook_payload: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False)
    processed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[Optional["User"]] = relationship(lazy="selectin")
