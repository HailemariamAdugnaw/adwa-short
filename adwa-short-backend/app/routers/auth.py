from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.deps import get_current_user, get_settings_dict, get_int_setting
from app.models.revenue import Creator
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.auth import (
    ForgotPasswordRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)
from app.security import (
    create_access_token,
    create_password_reset_token,
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
    ident = (payload.identifier or payload.phone or payload.email or payload.username or "").strip()
    if not ident:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Identifier (phone, email, or username) required")

    stmt = select(User).options(selectinload(User.admin_profile)).where(
        or_(
            User.phone == ident,
            User.email.ilike(ident),
            User.display_name.ilike(ident),
        )
    )
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid phone/email/username or password")
    if not user.is_active or user.is_banned:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled or banned")

    # Resolve creator_id if bound to a creator profile
    creator_id = None
    if user.creator_profile:
        creator_id = user.creator_profile.id
    else:
        c_res = await db.execute(select(Creator.id).where(Creator.user_id == user.id))
        creator_id = c_res.scalar_one_or_none()
        if creator_id is None and user.email:
            c_res2 = await db.execute(select(Creator.id).where(Creator.email.ilike(user.email.strip())))
            creator_id = c_res2.scalar_one_or_none()

    settings = await get_settings_dict(db)
    max_devices = get_int_setting(settings, "max_devices_per_account", 2)
    paid_tier = await is_paid_tier(db, user.id)

    # Viewer accounts enforce device count limiter; admin/staff/creator console logins register device without blocking
    is_privileged_user = user.is_staff or user.role in ("admin", "super_admin", "staff", "creator") or creator_id is not None
    if not is_privileged_user:
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
    else:
        try:
            await register_or_touch_device(
                db,
                user,
                device_fingerprint=x_device_id,
                device_name=x_device_name,
                platform=x_platform,
                max_devices=999,
            )
        except Exception:
            pass

    await _ensure_wallet(db, user)
    await db.commit()

    access = create_access_token(
        str(user.id),
        extra={
            "role": user.role,
            "admin_role": user.admin_role,
            "creator_id": creator_id,
            "phone": user.phone,
            "email": user.email,
            "display_name": user.display_name,
        },
    )
    refresh = create_refresh_token(
        str(user.id),
        extra={
            "role": user.role,
            "admin_role": user.admin_role,
            "creator_id": creator_id,
        },
    )
    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        user_id=user.id,
        role=user.role,
        admin_role=user.admin_role,
        creator_id=creator_id,
        display_name=user.display_name,
        email=user.email,
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

    res = await db.execute(select(User).options(selectinload(User.admin_profile)).where(User.id == uid))
    user = res.scalar_one_or_none()
    if user is None or not user.is_active or user.is_banned:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account not available")

    creator_id = None
    if user.creator_profile:
        creator_id = user.creator_profile.id
    else:
        c_res = await db.execute(select(Creator.id).where(Creator.user_id == user.id))
        creator_id = c_res.scalar_one_or_none()

    access = create_access_token(
        str(user.id),
        extra={
            "role": user.role,
            "admin_role": user.admin_role,
            "creator_id": creator_id,
            "phone": user.phone,
            "email": user.email,
            "display_name": user.display_name,
        },
    )
    new_refresh = create_refresh_token(
        str(user.id),
        extra={
            "role": user.role,
            "admin_role": user.admin_role,
            "creator_id": creator_id,
        },
    )
    return TokenResponse(
        access_token=access,
        refresh_token=new_refresh,
        user_id=user.id,
        role=user.role,
        admin_role=user.admin_role,
        creator_id=creator_id,
        display_name=user.display_name,
        email=user.email,
    )


@router.post("/forgot-password")
async def forgot_password(payload: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    email_clean = payload.email.strip()
    res = await db.execute(select(User).where(User.email.ilike(email_clean)))
    user = res.scalar_one_or_none()
    if user is None:
        return {
            "status": "ok",
            "message": "If this email is registered, password recovery instructions have been sent.",
            "reset_token": None,
        }
    reset_token = create_password_reset_token(str(user.id), user.email or email_clean)
    reset_url = f"/reset-password?token={reset_token}"
    return {
        "status": "ok",
        "message": "Password recovery email has been sent.",
        "reset_token": reset_token,
        "reset_url": reset_url,
    }


@router.post("/reset-password")
async def reset_password(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    try:
        decoded = decode_token(payload.token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset token")

    if decoded.get("type") != "password_reset":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid reset token type")

    user_id = decoded.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid reset token payload")

    try:
        uid = int(user_id)
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid reset token sub")

    res = await db.execute(select(User).where(User.id == uid))
    user = res.scalar_one_or_none()
    if user is None or not user.is_active or user.is_banned:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found or disabled")

    user.password_hash = hash_password(payload.new_password)
    await db.commit()
    return {"status": "ok", "message": "Password successfully updated. You can now sign in."}


@router.post("/logout")
async def logout(user: User = Depends(get_current_user)):
    return {"detail": "Logged out"}
