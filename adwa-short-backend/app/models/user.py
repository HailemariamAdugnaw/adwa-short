from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.utils.time import utcnow


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, index=True, nullable=False)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False, default="Viewer")
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    role: Mapped[str] = mapped_column(String(16), nullable=False, default="user", index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    wallet: Mapped[Optional["Wallet"]] = relationship(
        back_populates="user",
        uselist=False,
        lazy="selectin",
        cascade="all, delete-orphan",
    )
    devices: Mapped[List["Device"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    admin_profile: Mapped[Optional["AdminUser"]] = relationship(
        "AdminUser",
        back_populates="user",
        uselist=False,
        lazy="selectin",
        cascade="all, delete-orphan",
    )

    @property
    def admin_role(self) -> Optional[str]:
        if self.admin_profile and self.admin_profile.role_label:
            return self.admin_profile.role_label
        if self.role in ("super_admin", "staff"):
            return self.role
        if self.role == "admin":
            return "super_admin"
        return None

    @property
    def is_super_admin(self) -> bool:
        return self.admin_role == "super_admin"

    @property
    def is_staff(self) -> bool:
        return self.admin_role in ("staff", "super_admin")

    @property
    def balance_birr(self) -> float:
        return float(self.wallet.balance_birr) if self.wallet else 0.0

    @property
    def balance_coins(self) -> int:
        return int(self.wallet.balance_coins) if self.wallet else 0

    def __repr__(self) -> str:
        return f"<User id={self.id} phone={self.phone} role={self.role}>"


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    device_fingerprint: Mapped[str] = mapped_column(String(255), nullable=False)
    device_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    platform: Mapped[str] = mapped_column(String(16), default="android", nullable=False)
    last_seen: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user: Mapped["User"] = relationship(back_populates="devices")

    __table_args__ = (
    )
