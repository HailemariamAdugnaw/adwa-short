from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user
from app.models.user import Device, User
from app.schemas.user import DeviceOut, DeviceRegister
from app.services.device_limiter import register_or_touch_device

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/register", response_model=DeviceOut, status_code=status.HTTP_201_CREATED)
async def register_device(
    payload: DeviceRegister,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    try:
        device, _ = await register_or_touch_device(
            db,
            user,
            device_fingerprint=payload.device_fingerprint,
            device_name=payload.device_name,
            platform=payload.platform,
            max_devices=10,
        )
    except Exception:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="MAX_DEVICE_LIMIT_REACHED")
    await db.commit()
    await db.refresh(device)
    return device


@router.get("", response_model=list[DeviceOut])
async def list_devices(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(select(Device).where(Device.user_id == user.id))
    return list(res.scalars().all())


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device(device_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    res = await db.execute(select(Device).where(Device.id == device_id, Device.user_id == user.id))
    device = res.scalar_one_or_none()
    if device is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")
    await db.delete(device)
    await db.commit()
