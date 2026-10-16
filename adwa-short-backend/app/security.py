from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict

import bcrypt
import jwt

from app.config import settings


def _truncate(secret: str) -> bytes:
    return secret.encode("utf-8")[:72]


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(_truncate(plain), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_truncate(plain), hashed.encode("utf-8"))
    except Exception:
        return False


def _create_token(sub: str, token_type: str, expires_delta: timedelta, extra: Dict[str, Any] | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload: Dict[str, Any] = {
        "sub": sub,
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)


def create_access_token(sub: str, extra: Dict[str, Any] | None = None) -> str:
    return _create_token(
        sub,
        "access",
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        extra,
    )


def create_refresh_token(sub: str, extra: Dict[str, Any] | None = None) -> str:
    return _create_token(
        sub,
        "refresh",
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        extra,
    )


def decode_token(token: str) -> Dict[str, Any]:
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALG])
