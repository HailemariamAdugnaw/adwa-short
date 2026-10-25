from __future__ import annotations

import random
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.deps import get_current_super_admin
from app.models.admin import AdminUser, AuditLog
from app.models.user import User
from app.models.wallet import Wallet
from app.schemas.staff import (
    StaffActivityListResponse,
    StaffActivityOut,
    StaffCreate,
    StaffOut,
    StaffUpdate,
)
from app.security import hash_password
from app.services.audit import log_activity
from app.utils.time import utcnow

router = APIRouter(prefix="/admin/staff", tags=["admin-staff"])


@router.get("", response_model=List[StaffOut])
async def list_staff(
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_super_admin),
):
    # Ensure current admin has an AdminUser row if missing
    existing_admin_profile = (
        await db.execute(select(AdminUser).where(AdminUser.user_id == current_admin.id))
    ).scalar_one_or_none()
    if existing_admin_profile is None:
        db.add(AdminUser(user_id=current_admin.id, role_label="super_admin", permissions="*"))
        await db.commit()

    # Query all admin_users with user relationship loaded
    res = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.user))
        .order_by(AdminUser.created_at.desc())
    )
    admin_users = res.scalars().all()

    out: List[StaffOut] = []
    for au in admin_users:
        if au.user:
            out.append(
                StaffOut(
                    id=au.id,
                    user_id=au.user_id,
                    name=au.user.display_name,
                    email=au.user.email,
                    phone=au.user.phone,
                    role_label=au.role_label,
                    permissions=au.permissions,
                    is_active=au.user.is_active,
                    created_at=au.created_at,
                )
            )
    return out


@router.get("/activity", response_model=StaffActivityListResponse)
async def list_staff_activity(
    staff_id: Optional[int] = Query(default=None),
    action: Optional[str] = Query(default=None),
    entity_type: Optional[str] = Query(default=None),
    q: Optional[str] = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    stmt = (
        select(AuditLog)
        .options(selectinload(AuditLog.admin))
        .order_by(AuditLog.created_at.desc())
    )
    count_stmt = select(func.count(AuditLog.id))

    if staff_id is not None:
        stmt = stmt.where(AuditLog.admin_id == staff_id)
        count_stmt = count_stmt.where(AuditLog.admin_id == staff_id)
    if action:
        stmt = stmt.where(AuditLog.action.ilike(f"%{action}%"))
        count_stmt = count_stmt.where(AuditLog.action.ilike(f"%{action}%"))
    if entity_type:
        stmt = stmt.where(AuditLog.entity_type == entity_type)
        count_stmt = count_stmt.where(AuditLog.entity_type == entity_type)
    if q:
        pat = f"%{q}%"
        stmt = stmt.where(AuditLog.details.ilike(pat))
        count_stmt = count_stmt.where(AuditLog.details.ilike(pat))

    total = int((await db.execute(count_stmt)).scalar_one() or 0)
    res = await db.execute(stmt.offset((page - 1) * limit).limit(limit))
    logs = res.scalars().all()

    items: List[StaffActivityOut] = []
    for l in logs:
        admin_user = l.admin
        name = admin_user.display_name or admin_user.phone or "Unknown Staff" if admin_user else "System / Removed Staff"
        email = admin_user.email if admin_user else None
        role = admin_user.admin_role if admin_user else "staff"
        items.append(
            StaffActivityOut(
                id=l.id,
                admin_id=l.admin_id,
                admin_name=name,
                admin_email=email,
                admin_role=role,
                action=l.action,
                entity_type=l.entity_type,
                entity_id=l.entity_id,
                details=l.details,
                created_at=l.created_at,
            )
        )

    return StaffActivityListResponse(items=items, total=total, page=page, limit=limit)


@router.post("", response_model=StaffOut, status_code=status.HTTP_201_CREATED)
async def create_staff(
    payload: StaffCreate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_super_admin),
):
    # Check if email is already taken
    email_res = await db.execute(select(User).where(User.email == payload.email))
    if email_res.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this email address already exists",
        )

    # Check or generate phone
    phone = payload.phone
    if phone:
        phone_res = await db.execute(select(User).where(User.phone == phone))
        if phone_res.scalar_one_or_none() is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A user with this phone number already exists",
            )
    else:
        # Generate synthetic unique staff phone
        unique_found = False
        for _ in range(10):
            cand = f"+25199{random.randint(1000000, 9999999)}"
            p_res = await db.execute(select(User).where(User.phone == cand))
            if p_res.scalar_one_or_none() is None:
                phone = cand
                unique_found = True
                break
        if not unique_found:
            phone = f"+staff{int(utcnow().timestamp())}"

    user = User(
        phone=phone,
        email=payload.email,
        password_hash=hash_password(payload.password),
        display_name=payload.name,
        role="admin",
        is_active=True,
    )
    db.add(user)
    await db.flush()

    # Create admin profile
    admin_user = AdminUser(
        user_id=user.id,
        role_label=payload.role_label,
        permissions=payload.permissions or ("*" if payload.role_label == "super_admin" else "content"),
    )
    db.add(admin_user)

    # Create wallet
    db.add(Wallet(user_id=user.id, balance_birr=0, balance_coins=0))

    await log_activity(
        db,
        current_admin,
        "create",
        "staff",
        user.id,
        f"Created staff account '{user.email}' with role '{payload.role_label}'",
    )

    await db.commit()
    await db.refresh(admin_user)

    return StaffOut(
        id=admin_user.id,
        user_id=user.id,
        name=user.display_name,
        email=user.email,
        phone=user.phone,
        role_label=admin_user.role_label,
        permissions=admin_user.permissions,
        is_active=user.is_active,
        created_at=admin_user.created_at,
    )


@router.get("/{staff_id}", response_model=StaffOut)
async def get_staff(
    staff_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.user))
        .where(or_(AdminUser.id == staff_id, AdminUser.user_id == staff_id))
    )
    au = res.scalar_one_or_none()
    if au is None or not au.user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff account not found")

    return StaffOut(
        id=au.id,
        user_id=au.user_id,
        name=au.user.display_name,
        email=au.user.email,
        phone=au.user.phone,
        role_label=au.role_label,
        permissions=au.permissions,
        is_active=au.user.is_active,
        created_at=au.created_at,
    )


@router.put("/{staff_id}", response_model=StaffOut)
async def update_staff(
    staff_id: int,
    payload: StaffUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.user))
        .where(or_(AdminUser.id == staff_id, AdminUser.user_id == staff_id))
    )
    au = res.scalar_one_or_none()
    if au is None or not au.user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff account not found")

    user = au.user

    # Prevent demoting oneself
    if user.id == current_admin.id and payload.role_label and payload.role_label != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot demote your own super admin account",
        )

    # Check email conflict
    if payload.email and payload.email != user.email:
        exist = await db.execute(select(User).where(User.email == payload.email, User.id != user.id))
        if exist.scalar_one_or_none() is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already taken")
        user.email = payload.email

    # Check phone conflict
    if payload.phone and payload.phone != user.phone:
        exist = await db.execute(select(User).where(User.phone == payload.phone, User.id != user.id))
        if exist.scalar_one_or_none() is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Phone already taken")
        user.phone = payload.phone

    if payload.name:
        user.display_name = payload.name
    if payload.password:
        user.password_hash = hash_password(payload.password)
    if payload.is_active is not None:
        if user.id == current_admin.id and not payload.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot deactivate your own account",
            )
        user.is_active = payload.is_active

    if payload.role_label:
        au.role_label = payload.role_label
    if payload.permissions is not None:
        au.permissions = payload.permissions

    await log_activity(
        db,
        current_admin,
        "update",
        "staff",
        user.id,
        f"Updated staff account '{user.email}'",
    )

    await db.commit()
    await db.refresh(au)
    await db.refresh(user)

    return StaffOut(
        id=au.id,
        user_id=user.id,
        name=user.display_name,
        email=user.email,
        phone=user.phone,
        role_label=au.role_label,
        permissions=au.permissions,
        is_active=user.is_active,
        created_at=au.created_at,
    )


@router.post("/{staff_id}/toggle-active", response_model=StaffOut)
async def toggle_staff_active(
    staff_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.user))
        .where(or_(AdminUser.id == staff_id, AdminUser.user_id == staff_id))
    )
    au = res.scalar_one_or_none()
    if au is None or not au.user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff account not found")

    user = au.user
    if user.id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot toggle status of your own account",
        )

    user.is_active = not user.is_active
    await log_activity(
        db,
        current_admin,
        "toggle_active",
        "staff",
        user.id,
        f"Toggled staff account '{user.email}' to {'active' if user.is_active else 'deactivated'}",
    )
    await db.commit()
    await db.refresh(user)

    return StaffOut(
        id=au.id,
        user_id=user.id,
        name=user.display_name,
        email=user.email,
        phone=user.phone,
        role_label=au.role_label,
        permissions=au.permissions,
        is_active=user.is_active,
        created_at=au.created_at,
    )


@router.delete("/{staff_id}")
async def delete_staff(
    staff_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_super_admin),
):
    res = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.user))
        .where(or_(AdminUser.id == staff_id, AdminUser.user_id == staff_id))
    )
    au = res.scalar_one_or_none()
    if au is None or not au.user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff account not found")

    if au.user_id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete your own super admin account",
        )

    staff_email = au.user.email
    staff_user_id = au.user_id
    # Delete the user; cascade removes AdminUser and Wallet
    await db.delete(au.user)
    await log_activity(
        db,
        current_admin,
        "delete",
        "staff",
        staff_user_id,
        f"Deleted staff account '{staff_email}'",
    )
    await db.commit()

    return {"detail": "Staff account deleted successfully"}
