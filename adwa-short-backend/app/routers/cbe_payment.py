from __future__ import annotations

import json
import logging
import uuid
from datetime import timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.deps import get_current_super_admin, get_current_user
from app.models.cbe_payment import CbePaymentOrder
from app.models.revenue import RevenueTransaction
from app.models.settings import AppSettings
from app.models.subscription import Subscription, SubscriptionPlan, TimePass, TimePassPurchase
from app.models.user import User
from app.models.wallet import CoinPackage, CoinPurchase, Wallet, WalletTransaction
from app.schemas.cbe_payment import (
    CbeOrderStatusResponse,
    CbePaymentInitiateRequest,
    CbePaymentInitiateResponse,
    CbePaymentOrderOut,
    CbeWebhookPayload,
)
from app.services.cbe_gateway import cbe_gateway
from app.services.monetization import get_user_active_pass, get_user_active_subscription
from app.utils.time import ensure_utc, utcnow

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/payments/cbe", tags=["cbe-payments"])
alias_router = APIRouter(prefix="/payments/cbe", tags=["cbe-payments-alias"])


async def _get_or_create_wallet(db: AsyncSession, user_id: int) -> Wallet:
    res = await db.execute(select(Wallet).where(Wallet.user_id == user_id))
    wallet = res.scalar_one_or_none()
    if wallet is None:
        wallet = Wallet(user_id=user_id, balance_birr=0.0, balance_coins=0)
        db.add(wallet)
        await db.flush()
    return wallet


async def _resolve_creator_split_pct(db: AsyncSession) -> float:
    res = await db.execute(select(AppSettings).where(AppSettings.key == "default_creator_split_pct"))
    setting = res.scalar_one_or_none()
    if setting and setting.value:
        try:
            return float(setting.value)
        except ValueError:
            pass
    return settings.CBE_CREATOR_RESERVE_SPLIT_PCT


@router.post("/initiate", response_model=CbePaymentInitiateResponse, status_code=status.HTTP_201_CREATED)
@alias_router.post("/initiate", response_model=CbePaymentInitiateResponse, status_code=status.HTTP_201_CREATED)
async def initiate_payment(
    payload: CbePaymentInitiateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Initiates an automated payment request with Commercial Bank of Ethiopia (CBE / CBE Birr)."""
    if not settings.CBE_ENABLED:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="CBE payment gateway is disabled")

    amount_birr: float = 0.0
    desc_str: str = ""

    if payload.item_type == "coins":
        if not payload.item_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="package_id required for coins")
        res = await db.execute(select(CoinPackage).where(CoinPackage.id == payload.item_id))
        pkg = res.scalar_one_or_none()
        if not pkg or not pkg.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Coin package not found or inactive")
        amount_birr = float(pkg.price_birr)
        desc_str = f"Adwa Short - Buy {pkg.coins} Coins ({pkg.name})"

    elif payload.item_type == "time_pass":
        if not payload.item_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="pass_id required for time pass")
        res = await db.execute(select(TimePass).where(TimePass.id == payload.item_id))
        tpass = res.scalar_one_or_none()
        if not tpass or not tpass.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Time pass not found or inactive")
        amount_birr = float(tpass.price_birr)
        desc_str = f"Adwa Short - Time Pass: {tpass.name} ({tpass.duration_hours}h)"

    elif payload.item_type == "subscription":
        if not payload.item_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="plan_id required for subscription")
        active_sub = await get_user_active_subscription(db, user.id)
        if active_sub is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You already have an active subscription ({active_sub.plan.name if active_sub.plan else 'Active'}). Subscriptions renew automatically, so duplicate active purchases are restricted.",
            )
        res = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == payload.item_id))
        plan = res.scalar_one_or_none()
        if not plan or not plan.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subscription plan not found or inactive")
        amount_birr = float(plan.price_birr)
        desc_str = f"Adwa Short - Subscription: {plan.name} ({plan.billing_cycle})"

    elif payload.item_type == "wallet_deposit":
        if not payload.amount_birr or payload.amount_birr <= 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Valid amount_birr required for wallet deposit")
        amount_birr = float(payload.amount_birr)
        desc_str = f"Adwa Short - Wallet Deposit ETB {amount_birr:.2f}"

    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported item_type: {payload.item_type}")

    order_id = f"CBE-ORD-{uuid.uuid4().hex[:12].upper()}"
    customer_phone = payload.phone or user.phone

    cbe_res = await cbe_gateway.initiate_checkout(
        order_id=order_id,
        amount_birr=amount_birr,
        description=desc_str,
        phone=customer_phone,
    )

    order = CbePaymentOrder(
        order_id=order_id,
        user_id=user.id,
        item_type=payload.item_type,
        item_id=payload.item_id,
        amount_birr=amount_birr,
        currency="ETB",
        status="pending",
        bill_reference=cbe_res.get("bill_reference"),
        checkout_url=cbe_res.get("checkout_url"),
        ussd_code=cbe_res.get("ussd_code"),
        signature=cbe_res.get("signature"),
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    return CbePaymentInitiateResponse(
        order_id=order.order_id,
        item_type=order.item_type,
        item_id=order.item_id,
        amount_birr=float(order.amount_birr),
        currency=order.currency,
        status=order.status,
        bill_reference=order.bill_reference or "",
        checkout_url=order.checkout_url or "",
        ussd_code=order.ussd_code or "",
        created_at=order.created_at,
    )


@router.post("/webhook")
@router.post("/postback")
@alias_router.post("/webhook")
@alias_router.post("/postback")
async def handle_cbe_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_cbe_signature: Optional[str] = Header(None, alias="X-CBE-Signature"),
    x_signature: Optional[str] = Header(None, alias="X-Signature"),
    x_cbe_secret: Optional[str] = Header(None, alias="X-CBE-Secret"),
    authorization: Optional[str] = Header(None),
):
    """
    Receives real-time Server-to-Server (S2S) transaction notifications from CBE.
    Cryptographically verifies the webhook signature/token and ensures idempotency.
    """
    raw_body = await request.body()
    try:
        data: Dict[str, Any] = json.loads(raw_body.decode("utf-8")) if raw_body else {}
    except Exception:
        data = dict(request.query_params)

    order_id = data.get("order_id") or request.query_params.get("order_id")
    if not order_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing order_id in webhook payload")

    # Find the order
    res = await db.execute(select(CbePaymentOrder).where(CbePaymentOrder.order_id == order_id))
    order = res.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Order {order_id} not found")

    # Resolve signature and token
    received_sig = (
        x_cbe_signature
        or x_signature
        or data.get("signature")
        or request.query_params.get("signature")
        or request.query_params.get("sig")
    )
    secret_token = x_cbe_secret or request.query_params.get("secret")
    if not secret_token and authorization:
        parts = authorization.split()
        if len(parts) == 2 and parts[0].lower() == "bearer":
            secret_token = parts[1]

    # Verify cryptographic signature or secret token
    is_valid = False
    if secret_token and (secret_token == settings.CBE_WEBHOOK_SECRET or secret_token == settings.CBE_SECRET_KEY):
        is_valid = True
    elif received_sig:
        ts = data.get("timestamp") or request.query_params.get("timestamp")
        is_valid = cbe_gateway.verify_webhook_signature(
            order_id=order_id,
            amount_birr=float(order.amount_birr),
            received_signature=received_sig,
            timestamp=ts,
            raw_body=raw_body,
        )

    if not is_valid:
        logger.warning("CBE Webhook verification failed for order %s. Signature rejected.", order_id)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid CBE webhook cryptographic signature")

    cbe_tx_id = (
        data.get("cbe_transaction_id")
        or data.get("transaction_id")
        or data.get("cbe_ref")
        or data.get("trans_id")
        or f"CBE-TX-{order_id[-8:]}"
    )

    # Idempotency Check: prevent duplicate fulfillment of the same transaction
    if order.status == "completed":
        logger.info("Order %s already completed (idempotent response).", order_id)
        return {
            "status": "already_processed",
            "message": "Transaction already processed",
            "order_id": order.order_id,
            "cbe_transaction_id": order.cbe_transaction_id,
        }

    # Also check if cbe_transaction_id was already processed by another order
    if cbe_tx_id:
        tx_check = await db.execute(
            select(CbePaymentOrder).where(
                CbePaymentOrder.cbe_transaction_id == cbe_tx_id,
                CbePaymentOrder.status == "completed",
            )
        )
        if tx_check.scalar_one_or_none():
            logger.info("CBE transaction hash %s already processed (idempotent).", cbe_tx_id)
            return {
                "status": "already_processed",
                "message": "CBE transaction hash already processed",
                "order_id": order.order_id,
                "cbe_transaction_id": cbe_tx_id,
            }

    tx_status = str(data.get("status", "COMPLETED")).upper()

    if tx_status in ("COMPLETED", "SUCCESS", "PAID"):
        now = utcnow()
        gross_birr = float(order.amount_birr)

        # 1. Instant Item Fulfillment
        if order.item_type == "coins":
            wallet = await _get_or_create_wallet(db, order.user_id)
            pkg_res = await db.execute(select(CoinPackage).where(CoinPackage.id == order.item_id))
            pkg = pkg_res.scalar_one_or_none()
            coins_to_add = int(pkg.coins) if pkg else int(gross_birr)
            wallet.balance_coins = int(wallet.balance_coins or 0) + coins_to_add
            db.add(
                WalletTransaction(
                    wallet_id=wallet.id,
                    type="cbe_coin_purchase",
                    amount_birr=gross_birr,
                    amount_coins=coins_to_add,
                    description=f"CBE Birr purchase: {pkg.name if pkg else 'Coins'}",
                    reference=order.order_id,
                )
            )
            db.add(
                CoinPurchase(
                    user_id=order.user_id,
                    package_id=pkg.id if pkg else None,
                    coins=coins_to_add,
                    price_birr=gross_birr,
                )
            )

        elif order.item_type == "time_pass":
            pass_res = await db.execute(select(TimePass).where(TimePass.id == order.item_id))
            tpass = pass_res.scalar_one_or_none()
            duration_hours = int(tpass.duration_hours) if tpass else 24
            active_pass = await get_user_active_pass(db, order.user_id)
            base_time = ensure_utc(active_pass.expires_at) if (active_pass and ensure_utc(active_pass.expires_at) > now) else now
            db.add(
                TimePassPurchase(
                    user_id=order.user_id,
                    pass_id=tpass.id if tpass else order.item_id,
                    starts_at=now,
                    expires_at=base_time + timedelta(hours=duration_hours),
                    is_active=True,
                )
            )

        elif order.item_type == "subscription":
            plan_res = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == order.item_id))
            plan = plan_res.scalar_one_or_none()
            days = 365 if (plan and plan.billing_cycle == "yearly") else 30
            db.add(
                Subscription(
                    user_id=order.user_id,
                    plan_id=plan.id if plan else order.item_id,
                    status="active",
                    started_at=now,
                    next_billing_at=now + timedelta(days=days),
                )
            )

        elif order.item_type == "wallet_deposit":
            wallet = await _get_or_create_wallet(db, order.user_id)
            wallet.balance_birr = float(wallet.balance_birr or 0) + gross_birr
            db.add(
                WalletTransaction(
                    wallet_id=wallet.id,
                    type="cbe_deposit",
                    amount_birr=gross_birr,
                    amount_coins=0,
                    description="CBE Birr automated deposit",
                    reference=order.order_id,
                )
            )

        # 2. Financial Ledger Recording with Platform Treasury & Creator Pool Segregation
        # Both Time Passes and Subscriptions are held in Platform Treasury initially;
        # creator shares are attributed prorated by actual watch-time (or 100% platform retained for unconsumed duration)
        if order.item_type in ("subscription", "time_pass"):
            creator_pool_reserve_birr = 0.0
            platform_share_birr = gross_birr
        else:
            split_pct = await _resolve_creator_split_pct(db)
            creator_pool_reserve_birr = round(gross_birr * (split_pct / 100.0), 2)
            platform_share_birr = round(gross_birr - creator_pool_reserve_birr, 2)

        rev_tx = RevenueTransaction(
            creator_id=None,
            user_id=order.user_id,
            source_type=f"cbe_{order.item_type}",
            gross_amount_birr=gross_birr,
            creator_share_birr=creator_pool_reserve_birr,  # Creator revenue pool reserve
            platform_share_birr=platform_share_birr,        # Platform net retained treasury revenue
            reference=f"cbe:{order.order_id}:tx:{cbe_tx_id}",
        )
        db.add(rev_tx)

        # 3. Update Order Status
        order.status = "completed"
        order.cbe_transaction_id = cbe_tx_id
        order.payer_phone = data.get("payer_phone")
        order.payer_account = data.get("payer_account")
        order.processed_at = now
        order.webhook_payload = json.dumps(data)
        await db.commit()

        logger.info(
            "CBE payment verified successfully for order %s (TX: %s, ETB %.2f).",
            order_id,
            cbe_tx_id,
            gross_birr,
        )

        return {
            "status": "success",
            "message": "CBE payment verified and fulfilled successfully",
            "order_id": order.order_id,
            "cbe_transaction_id": cbe_tx_id,
            "amount_birr": gross_birr,
            "platform_share_birr": platform_share_birr,
            "creator_pool_reserve_birr": creator_pool_reserve_birr,
        }

    else:
        # Payment Failed or Canceled
        order.status = "failed"
        order.processed_at = utcnow()
        order.webhook_payload = json.dumps(data)
        await db.commit()
        return {
            "status": "failed",
            "message": "Payment recorded as failed/canceled",
            "order_id": order.order_id,
        }


@router.get("/order/{order_id}", response_model=CbeOrderStatusResponse)
@alias_router.get("/order/{order_id}", response_model=CbeOrderStatusResponse)
async def get_order_status(
    order_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Retrieves live payment order status (polled by mobile client after checkout)."""
    res = await db.execute(select(CbePaymentOrder).where(CbePaymentOrder.order_id == order_id))
    order = res.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Order {order_id} not found")

    return CbeOrderStatusResponse(
        order_id=order.order_id,
        item_type=order.item_type,
        item_id=order.item_id,
        amount_birr=float(order.amount_birr),
        currency=order.currency,
        status=order.status,
        cbe_transaction_id=order.cbe_transaction_id,
        bill_reference=order.bill_reference,
        checkout_url=order.checkout_url,
        ussd_code=order.ussd_code,
        created_at=order.created_at,
        processed_at=order.processed_at,
    )


@router.post("/simulate-payment/{order_id}")
@alias_router.post("/simulate-payment/{order_id}")
async def simulate_cbe_payment(
    order_id: str,
    db: AsyncSession = Depends(get_db),
):
    """
    Simulates an instant CBE Birr payment confirmation for development & automated testing.
    Generates a cryptographically valid payload and calls the webhook logic.
    """
    res = await db.execute(select(CbePaymentOrder).where(CbePaymentOrder.order_id == order_id))
    order = res.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Order {order_id} not found")

    mock_payload, sig = cbe_gateway.build_simulation_webhook(
        order_id=order.order_id,
        amount_birr=float(order.amount_birr),
    )

    # Process through the exact same webhook handler with valid signature
    class MockRequest:
        def __init__(self, p: dict):
            self._p = p
            self.query_params = {}

        async def body(self) -> bytes:
            return json.dumps(self._p).encode("utf-8")

    return await handle_cbe_webhook(
        request=MockRequest(mock_payload),
        db=db,
        x_cbe_signature=sig,
    )


@router.get("/admin/orders", response_model=List[CbePaymentOrderOut])
@alias_router.get("/admin/orders", response_model=List[CbePaymentOrderOut])
async def list_cbe_orders_admin(
    status_filter: Optional[str] = Query(default=None, alias="status"),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=50, le=200),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_super_admin),
):
    """Super Admin auditing endpoint for all CBE Birr transactions."""
    stmt = select(CbePaymentOrder)
    if status_filter:
        stmt = stmt.where(CbePaymentOrder.status == status_filter)
    stmt = stmt.order_by(desc(CbePaymentOrder.created_at)).limit(limit).offset((page - 1) * limit)
    res = await db.execute(stmt)
    return list(res.scalars().all())
