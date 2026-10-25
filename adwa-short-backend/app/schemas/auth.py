from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class RegisterRequest(BaseModel):
    phone: str = Field(min_length=6, max_length=32)
    password: str = Field(min_length=4, max_length=128)
    display_name: Optional[str] = Field(default=None, max_length=120)
    email: Optional[str] = Field(default=None, max_length=255)


class LoginRequest(BaseModel):
    phone: Optional[str] = None
    email: Optional[str] = None
    username: Optional[str] = None
    identifier: Optional[str] = None
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: int
    role: str
    admin_role: Optional[str] = None
    creator_id: Optional[int] = None
    display_name: Optional[str] = None
    email: Optional[str] = None
    is_paid_tier: bool = False
    device_limit_enforced: bool = False


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=6, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutResponse(BaseModel):
    detail: str = "Logged out"


class DeviceHeader(BaseModel):
    device_id: str
    device_name: Optional[str] = None
    platform: str = "android"
