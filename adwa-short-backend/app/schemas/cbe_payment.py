from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class CbePaymentInitiateRequest(BaseModel):
    item_type: Literal["coins", "time_pass", "subscription", "wallet_deposit"]
    item_id: Optional[int] = Field(default=None, description="ID of CoinPackage, TimePass, or SubscriptionPlan")
    amount_birr: Optional[float] = Field(default=None, description="Amount in ETB (required for wallet_deposit)")
    phone: Optional[str] = Field(default=None, description="Optional customer phone number for CBE Birr push")


class CbePaymentInitiateResponse(BaseModel):
    order_id: str
    item_type: str
    item_id: Optional[int]
    amount_birr: float
    currency: str = "ETB"
    status: str
    bill_reference: str
    checkout_url: str
    ussd_code: str
    created_at: datetime


class CbeWebhookPayload(BaseModel):
    order_id: str
    cbe_transaction_id: str
    amount_birr: float
    currency: str = "ETB"
    status: str = "COMPLETED"  # COMPLETED, SUCCESS, PAID, FAILED, CANCELED
    payer_phone: Optional[str] = None
    payer_account: Optional[str] = None
    timestamp: Optional[str] = None
    signature: Optional[str] = None


class CbeOrderStatusResponse(BaseModel):
    order_id: str
    item_type: str
    item_id: Optional[int]
    amount_birr: float
    currency: str = "ETB"
    status: str
    cbe_transaction_id: Optional[str] = None
    bill_reference: Optional[str] = None
    checkout_url: Optional[str] = None
    ussd_code: Optional[str] = None
    created_at: datetime
    processed_at: Optional[datetime] = None


class CbePaymentOrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    order_id: str
    user_id: int
    item_type: str
    item_id: Optional[int]
    amount_birr: float
    currency: str
    status: str
    cbe_transaction_id: Optional[str]
    bill_reference: Optional[str]
    checkout_url: Optional[str]
    ussd_code: Optional[str]
    payer_phone: Optional[str]
    payer_account: Optional[str]
    created_at: datetime
    processed_at: Optional[datetime]
