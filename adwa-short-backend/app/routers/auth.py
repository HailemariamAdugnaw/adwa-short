from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user, get_settings_dict, get_int_setting
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse
from app.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.services.device_limiter import DeviceLimitError, is_paid_tier, register_or_touch_device

router = APIRouter(prefix="/auth", tags=["auth"])


async def _ensure_wallet(db: AsyncSession, user: User) -> Wallet:
    res = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet = res.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user.id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()
    return wallet


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(select(User).where(User.phone == payload.phone))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Phone already registered")

    user = User(
        phone=payload.phone,
        email=payload.email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name or "Viewer",
        role="user",
        is_active=True,
    )
    db.add(user)
    await db.flush()
    await _ensure_wallet(db, user)
    await db.commit()

    access = create_access_token(str(user.id), extra={"role": user.role, "phone": user.phone})
    refresh = create_refresh_token(str(user.id), extra={"role": user.role})
    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        user_id=user.id,
        role=user.role,
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    x_device_id: str = Header(..., alias="X-Device-Id"),
    x_device_name: str | None = Header(default=None, alias="X-Device-Name"),
    x_platform: str = Header(default="android", alias="X-Platform"),
    db: AsyncSession = Depends(get_db),
):
    res = await db.execute(select(User).where(User.phone == payload.phone))
    user = res.scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid phone or password")
    if not user.is_active or user.is_banned:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled or banned")

    settings = await get_settings_dict(db)
    max_devices = get_int_setting(settings, "max_devices_per_account", 2)
    paid_tier = await is_paid_tier(db, user.id)

    try:
        await register_or_touch_device(
            db,
            user,
            device_fingerprint=x_device_id,
            device_name=x_device_name,
            platform=x_platform,
            max_devices=max_devices,
        )
    except DeviceLimitError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="MAX_DEVICE_LIMIT_REACHED",
        )

    await _ensure_wallet(db, user)
    await db.commit()

    access = create_access_token(str(user.id), extra={"role": user.role, "phone": user.phone})
    refresh = create_refresh_token(str(user.id), extra={"role": user.role})
    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        user_id=user.id,
        role=user.role,
        is_paid_tier=paid_tier,
        device_limit_enforced=paid_tier,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshRequest, db: AsyncSession = Depends(get_db)):
    try:
        decoded = decode_token(payload.refresh_token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    if decoded.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    try:
        uid = int(decoded.get("sub"))
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    res = await db.execute(select(User).where(User.id == uid))
    user = res.scalar_one_or_none()
    if user is None or not user.is_active or user.is_banned:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account not available")

    access = create_access_token(str(user.id), extra={"role": user.role, "phone": user.phone})
    new_refresh = create_refresh_token(str(user.id), extra={"role": user.role})
    return TokenResponse(
        access_token=access,
        refresh_token=new_refresh,
        user_id=user.id,
        role=user.role,
    )


@router.post("/logout")
async def logout(user: User = Depends(get_current_user)):
    return {"detail": "Logged out"}
