from __future__ import annotations

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class StaffCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: str = Field(min_length=5, max_length=255)
    phone: Optional[str] = Field(default=None, max_length=32)
    password: str = Field(min_length=6, max_length=128)
    role_label: str = Field(default="staff", pattern="^(staff|super_admin)$")
    permissions: Optional[str] = "content"


class StaffUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=2, max_length=120)
    email: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = Field(default=None, min_length=6, max_length=128)
    role_label: Optional[str] = Field(default=None, pattern="^(staff|super_admin)$")
    permissions: Optional[str] = None
    is_active: Optional[bool] = None


class StaffOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    role_label: str
    permissions: Optional[str] = None
    is_active: bool
    created_at: datetime


class StaffActivityOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    admin_id: Optional[int] = None
    admin_name: str
    admin_email: Optional[str] = None
    admin_role: str
    action: str
    entity_type: str
    entity_id: Optional[int] = None
    details: Optional[str] = None
    created_at: datetime


class StaffActivityListResponse(BaseModel):
    items: list[StaffActivityOut]
    total: int
    page: int
    limit: int
