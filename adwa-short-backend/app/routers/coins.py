from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_admin, get_current_user
from app.models.content import Episode, Series
from app.models.user import User
from app.models.wallet import CoinPackage, CoinPurchase, Wallet, WalletTransaction
from app.schemas.wallet import (
    CoinPackageCreate,
    CoinPackageOut,
    CoinPackageUpdate,
    CoinPurchaseRequest,
    CoinSpendRequest,
    CoinSpendResponse,
)
from app.services.monetization import AccessDenied, resolve_access

router = APIRouter(prefix="/coins", tags=["coins"])


@router.get("/packages", response_model=List[CoinPackageOut])
async def list_packages(db: AsyncSession = Depends(get_db)):
    res = await db.execute(
        select(CoinPackage).where(CoinPackage.is_active.is_(True)).order_by(CoinPackage.sort_order)
    )
    return list(res.scalars().all())


@router.post("/purchase", response_model=CoinSpendResponse)
async def purchase_coins(
    payload: CoinPurchaseRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(CoinPackage).where(CoinPackage.id == payload.package_id))
    pkg = res.scalar_one_or_none()
    if pkg is None or not pkg.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Coin package not found")

    wres = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet = wres.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user.id, balance_birr=0, balance_coins=0)
        db.add(wallet)
        await db.flush()

    if float(wallet.balance_birr) < float(pkg.price_birr):
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Insufficient Birr balance")

    wallet.balance_birr = float(wallet.balance_birr) - float(pkg.price_birr)
    wallet.balance_coins = int(wallet.balance_coins or 0) + int(pkg.coins)

    db.add(
        WalletTransaction(
            wallet_id=wallet.id,
            type="purchase",
            amount_birr=-float(pkg.price_birr),
            amount_coins=int(pkg.coins),
            description=f"Purchased {pkg.name}",
            reference=f"coin_pkg:{pkg.id}",
        )
    )
    db.add(CoinPurchase(user_id=user.id, package_id=pkg.id, coins=int(pkg.coins), price_birr=float(pkg.price_birr)))
    await db.commit()
    return CoinSpendResponse(success=True, new_balance_coins=int(wallet.balance_coins), episode_id=0)


@router.post("/spend", response_model=CoinSpendResponse)
async def spend_coins(
    payload: CoinSpendRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    res = await db.execute(select(Episode).where(Episode.id == payload.episode_id))
    ep = res.scalar_one_or_none()
    if ep is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Episode not found")
    sres = await db.execute(select(Series).where(Series.id == ep.series_id))
    series = sres.scalar_one_or_none()
    if series is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Series not found")
    try:
        result = await resolve_access(db, user, ep, series, deduct_coins=True)
    except AccessDenied as e:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=e.reason.value)
    await db.commit()
    wres = await db.execute(select(Wallet).where(Wallet.user_id == user.id))
    wallet = wres.scalar_one_or_none()
    return CoinSpendResponse(
        success=True,
        new_balance_coins=int(wallet.balance_coins if wallet else 0),
        episode_id=ep.id,
    )


@router.post("/packages", response_model=CoinPackageOut, status_code=status.HTTP_201_CREATED)
async def create_package(
    payload: CoinPackageCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    pkg = CoinPackage(**payload.model_dump())
    db.add(pkg)
    await db.commit()
    await db.refresh(pkg)
    return pkg


@router.put("/packages/{package_id}", response_model=CoinPackageOut)
async def update_package(
    package_id: int,
    payload: CoinPackageUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(CoinPackage).where(CoinPackage.id == package_id))
    pkg = res.scalar_one_or_none()
    if pkg is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Coin package not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(pkg, k, v)
    await db.commit()
    await db.refresh(pkg)
    return pkg


@router.delete("/packages/{package_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_package(
    package_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    res = await db.execute(select(CoinPackage).where(CoinPackage.id == package_id))
    pkg = res.scalar_one_or_none()
    if pkg is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Coin package not found")
    await db.delete(pkg)
    await db.commit()
