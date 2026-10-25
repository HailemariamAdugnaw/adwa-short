from __future__ import annotations

from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.admin import AuditLog
from app.models.user import User


async def log_activity(
    db: AsyncSession,
    user: User,
    action: str,
    entity_type: str,
    entity_id: Optional[int] = None,
    details: Optional[str] = None,
) -> AuditLog:
    """Records administrative actions (especially content additions/updates by staff)."""
    entry = AuditLog(
        admin_id=user.id if user else None,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        details=details,
    )
    db.add(entry)
    return entry
