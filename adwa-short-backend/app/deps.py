from __future__ import annotations

from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.settings import AppSettings as SettingsModel
from app.models.user import User
from app.security import decode_token

bearer_scheme = HTTPBearer(auto_error=False)

CREDENTIAL_ERROR = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    if creds is None or not creds.credentials:
        raise CREDENTIAL_ERROR
    try:
        payload = decode_token(creds.credentials)
    except Exception:
        raise CREDENTIAL_ERROR

    if payload.get("type") != "access":
        raise CREDENTIAL_ERROR

    user_id = payload.get("sub")
    if user_id is None:
        raise CREDENTIAL_ERROR

    try:
        uid = int(user_id)
    except (TypeError, ValueError):
        raise CREDENTIAL_ERROR

    result = await db.execute(select(User).where(User.id == uid))
    user = result.scalar_one_or_none()
    if user is None:
        raise CREDENTIAL_ERROR
    if not user.is_active or user.is_banned:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is disabled or banned")
    return user


async def get_current_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    return user


async def get_optional_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    if creds is None or not creds.credentials:
        return None
    try:
        payload = decode_token(creds.credentials)
    except Exception:
        return None
    if payload.get("type") != "access":
        return None
    try:
        uid = int(payload.get("sub"))
    except (TypeError, ValueError):
        return None
    result = await db.execute(select(User).where(User.id == uid))
    return result.scalar_one_or_none()


async def get_settings_dict(db: AsyncSession) -> dict:
    result = await db.execute(select(SettingsModel))
    rows = result.scalars().all()
    return {row.key: row.value for row in rows}


def get_setting_value(settings_dict: dict, key: str, default: str) -> str:
    return settings_dict.get(key, default)


def get_int_setting(settings_dict: dict, key: str, default: int) -> int:
    try:
        return int(settings_dict.get(key, default))
    except (TypeError, ValueError):
        return default


def get_bool_setting(settings_dict: dict, key: str, default: bool) -> bool:
    raw = settings_dict.get(key, str(default))
    return str(raw).strip().lower() in {"1", "true", "yes", "on"}
