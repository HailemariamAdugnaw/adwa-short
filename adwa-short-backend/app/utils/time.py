from __future__ import annotations

from datetime import datetime, timedelta, timezone


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def hours_from_now(hours: float) -> datetime:
    return utcnow() + timedelta(hours=hours)


def days_from_now(days: float) -> datetime:
    return utcnow() + timedelta(days=days)


def is_expired(dt: datetime | None) -> bool:
    if dt is None:
        return True
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt <= utcnow()
