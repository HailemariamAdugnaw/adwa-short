from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005_ad_configuration_and_impressions"
down_revision: Union[str, None] = "0004_creator_portal_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Expand ad_unlock_rules
    op.add_column("ad_unlock_rules", sa.Column("provider", sa.String(length=32), nullable=False, server_default="admob"))
    op.add_column("ad_unlock_rules", sa.Column("app_id", sa.String(length=255), nullable=True))
    op.add_column("ad_unlock_rules", sa.Column("banner_unit_id", sa.String(length=255), nullable=True))
    op.add_column("ad_unlock_rules", sa.Column("interstitial_unit_id", sa.String(length=255), nullable=True))
    op.add_column("ad_unlock_rules", sa.Column("rewarded_unit_id", sa.String(length=255), nullable=True))
    op.add_column("ad_unlock_rules", sa.Column("api_key", sa.String(length=255), nullable=True))
    op.add_column("ad_unlock_rules", sa.Column("callback_secret", sa.String(length=255), nullable=True))
    op.add_column("ad_unlock_rules", sa.Column("reward_ad_value_birr", sa.Numeric(10, 2), nullable=False, server_default="0.50"))
    op.add_column("ad_unlock_rules", sa.Column("estimated_cpm_birr", sa.Numeric(10, 2), nullable=False, server_default="50.00"))
    op.add_column("ad_unlock_rules", sa.Column("test_mode", sa.Boolean(), nullable=False, server_default=sa.text("true")))

    # 2. Expand ad_unlock_logs
    op.add_column("ad_unlock_logs", sa.Column("revenue_birr", sa.Numeric(10, 2), nullable=False, server_default="0.50"))
    op.add_column("ad_unlock_logs", sa.Column("ad_network", sa.String(length=32), nullable=True, server_default="admob"))
    op.add_column("ad_unlock_logs", sa.Column("verified_via", sa.String(length=32), nullable=False, server_default="client"))

    # 3. Create ad_impression_logs table
    op.create_table(
        "ad_impression_logs",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("episode_id", sa.Integer(), sa.ForeignKey("episodes.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("ad_unit_id", sa.String(length=255), nullable=True),
        sa.Column("ad_network", sa.String(length=32), nullable=False, server_default="admob"),
        sa.Column("ad_type", sa.String(length=32), nullable=False, server_default="rewarded"),
        sa.Column("revenue_birr", sa.Numeric(10, 4), nullable=False, server_default="0.05"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("ad_impression_logs")
    op.drop_column("ad_unlock_logs", "verified_via")
    op.drop_column("ad_unlock_logs", "ad_network")
    op.drop_column("ad_unlock_logs", "revenue_birr")
    op.drop_column("ad_unlock_rules", "test_mode")
    op.drop_column("ad_unlock_rules", "estimated_cpm_birr")
    op.drop_column("ad_unlock_rules", "reward_ad_value_birr")
    op.drop_column("ad_unlock_rules", "callback_secret")
    op.drop_column("ad_unlock_rules", "api_key")
    op.drop_column("ad_unlock_rules", "rewarded_unit_id")
    op.drop_column("ad_unlock_rules", "interstitial_unit_id")
    op.drop_column("ad_unlock_rules", "banner_unit_id")
    op.drop_column("ad_unlock_rules", "app_id")
    op.drop_column("ad_unlock_rules", "provider")
