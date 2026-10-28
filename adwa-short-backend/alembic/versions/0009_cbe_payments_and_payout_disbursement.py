"""cbe_payments_and_payout_disbursement

Revision ID: 0009_cbe_payments_and_payout_disbursement
Revises: 0008_series_coin_cost
Create Date: 2026-10-27 02:25:00
"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0009_cbe_payments_and_payout_disbursement"
down_revision: Union[str, None] = "0008_series_coin_cost"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    # 1. Payout table audit and CBE disbursement columns
    if "payouts" in tables:
        payout_columns = [col["name"] for col in inspector.get_columns("payouts")]

        if "cbe_transaction_id" not in payout_columns:
            op.add_column("payouts", sa.Column("cbe_transaction_id", sa.String(length=128), nullable=True))
            op.create_index("ix_payouts_cbe_transaction_id", "payouts", ["cbe_transaction_id"], unique=True)

        if "bank_account_number" not in payout_columns:
            op.add_column("payouts", sa.Column("bank_account_number", sa.String(length=64), nullable=True))

        if "bank_account_name" not in payout_columns:
            op.add_column("payouts", sa.Column("bank_account_name", sa.String(length=255), nullable=True))

        if "bank_name" not in payout_columns:
            op.add_column(
                "payouts",
                sa.Column(
                    "bank_name",
                    sa.String(length=120),
                    nullable=False,
                    server_default="Commercial Bank of Ethiopia (CBE)",
                ),
            )

        if "cbe_payout_status" not in payout_columns:
            op.add_column(
                "payouts",
                sa.Column(
                    "cbe_payout_status",
                    sa.String(length=32),
                    nullable=True,
                    server_default="pending",
                ),
            )

        if "treasury_account_number" not in payout_columns:
            op.add_column("payouts", sa.Column("treasury_account_number", sa.String(length=64), nullable=True))

        if "cbe_response_payload" not in payout_columns:
            op.add_column("payouts", sa.Column("cbe_response_payload", sa.Text(), nullable=True))

    # 2. CBE Payment Orders Table
    if "cbe_payment_orders" not in tables:
        op.create_table(
            "cbe_payment_orders",
            sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
            sa.Column("order_id", sa.String(length=64), nullable=False),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("item_type", sa.String(length=32), nullable=False),
            sa.Column("item_id", sa.Integer(), nullable=True),
            sa.Column("amount_birr", sa.Numeric(precision=12, scale=2), nullable=False),
            sa.Column("currency", sa.String(length=8), server_default="ETB", nullable=False),
            sa.Column("status", sa.String(length=32), server_default="pending", nullable=False),
            sa.Column("cbe_transaction_id", sa.String(length=128), nullable=True),
            sa.Column("bill_reference", sa.String(length=64), nullable=True),
            sa.Column("checkout_url", sa.String(length=512), nullable=True),
            sa.Column("ussd_code", sa.String(length=64), nullable=True),
            sa.Column("payer_phone", sa.String(length=32), nullable=True),
            sa.Column("payer_account", sa.String(length=64), nullable=True),
            sa.Column("signature", sa.String(length=255), nullable=True),
            sa.Column("webhook_payload", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index("ix_cbe_payment_orders_order_id", "cbe_payment_orders", ["order_id"], unique=True)
        op.create_index("ix_cbe_payment_orders_user_id", "cbe_payment_orders", ["user_id"], unique=False)
        op.create_index("ix_cbe_payment_orders_status", "cbe_payment_orders", ["status"], unique=False)
        op.create_index("ix_cbe_payment_orders_cbe_transaction_id", "cbe_payment_orders", ["cbe_transaction_id"], unique=True)
        op.create_index("ix_cbe_payment_orders_bill_reference", "cbe_payment_orders", ["bill_reference"], unique=False)

    # 3. Clean up obsolete static ad revenue columns from ad_unlock_rules if present
    if "ad_unlock_rules" in tables:
        rule_columns = [col["name"] for col in inspector.get_columns("ad_unlock_rules")]
        if "reward_ad_value_birr" in rule_columns:
            op.drop_column("ad_unlock_rules", "reward_ad_value_birr")
        if "estimated_cpm_birr" in rule_columns:
            op.drop_column("ad_unlock_rules", "estimated_cpm_birr")


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = inspector.get_table_names()

    if "cbe_payment_orders" in tables:
        op.drop_table("cbe_payment_orders")

    if "payouts" in tables:
        payout_columns = [col["name"] for col in inspector.get_columns("payouts")]
        if "cbe_transaction_id" in payout_columns:
            op.drop_index("ix_payouts_cbe_transaction_id", table_name="payouts")
            op.drop_column("payouts", "cbe_transaction_id")
        if "bank_account_number" in payout_columns:
            op.drop_column("payouts", "bank_account_number")
        if "bank_account_name" in payout_columns:
            op.drop_column("payouts", "bank_account_name")
        if "bank_name" in payout_columns:
            op.drop_column("payouts", "bank_name")
        if "cbe_payout_status" in payout_columns:
            op.drop_column("payouts", "cbe_payout_status")
        if "treasury_account_number" in payout_columns:
            op.drop_column("payouts", "treasury_account_number")
        if "cbe_response_payload" in payout_columns:
            op.drop_column("payouts", "cbe_response_payload")
