from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002_revenue_ratings_reviews"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "creators",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("name", sa.String(255), nullable=False, index=True),
        sa.Column("phone", sa.String(32), nullable=True, index=True),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("display_name", sa.String(255), nullable=True),
        sa.Column("avatar_url", sa.String(512), nullable=True),
        sa.Column("legal_contract_url", sa.String(512), nullable=True),
        sa.Column("contract_signed_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("bank_account_name", sa.String(255), nullable=True),
        sa.Column("bank_account_number", sa.String(64), nullable=True),
        sa.Column("bank_name", sa.String(120), nullable=True),
        sa.Column("payment_method", sa.String(32), nullable=True),
        sa.Column("default_revenue_split_pct", sa.Numeric(5, 2), nullable=False, server_default="50.00"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )

    with op.batch_alter_table("series", schema=None) as batch_op:
        batch_op.add_column(sa.Column("creator_id", sa.Integer(), nullable=True))
        batch_op.create_foreign_key("fk_series_creator_id", "creators", ["creator_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_series_creator_id", "series", ["creator_id"])
    with op.batch_alter_table("episodes", schema=None) as batch_op:
        batch_op.add_column(sa.Column("creator_id", sa.Integer(), nullable=True))
        batch_op.create_foreign_key("fk_episodes_creator_id", "creators", ["creator_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_episodes_creator_id", "episodes", ["creator_id"])

    op.create_table(
        "revenue_split_rules",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("creator_id", sa.Integer(), sa.ForeignKey("creators.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("series_id", sa.Integer(), sa.ForeignKey("series.id", ondelete="CASCADE"), nullable=True, index=True),
        sa.Column("episode_id", sa.Integer(), sa.ForeignKey("episodes.id", ondelete="CASCADE"), nullable=True, index=True),
        sa.Column("creator_share_pct", sa.Numeric(5, 2), nullable=False, server_default="50.00"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "payouts",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("creator_id", sa.Integer(), sa.ForeignKey("creators.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("amount_birr", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending", index=True),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("processed_by_admin_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("reference", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "revenue_transactions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("creator_id", sa.Integer(), sa.ForeignKey("creators.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("series_id", sa.Integer(), sa.ForeignKey("series.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("episode_id", sa.Integer(), sa.ForeignKey("episodes.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("source_type", sa.String(32), nullable=False, index=True),
        sa.Column("gross_amount_birr", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("creator_share_birr", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("platform_share_birr", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("reference", sa.String(255), nullable=True),
        sa.Column("payout_id", sa.Integer(), sa.ForeignKey("payouts.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, index=True),
    )

    op.create_table(
        "ratings",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("episode_id", sa.Integer(), sa.ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("series_id", sa.Integer(), sa.ForeignKey("series.id", ondelete="CASCADE"), nullable=True, index=True),
        sa.Column("rating", sa.SmallInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "episode_id", name="uq_user_episode_rating"),
    )

    op.create_table(
        "reviews",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("episode_id", sa.Integer(), sa.ForeignKey("episodes.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("series_id", sa.Integer(), sa.ForeignKey("series.id", ondelete="CASCADE"), nullable=True, index=True),
        sa.Column("text", sa.String(2000), nullable=False),
        sa.Column("is_approved", sa.Boolean(), nullable=False, server_default=sa.text("true"), index=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )

    with op.batch_alter_table("view_logs", schema=None) as batch_op:
        batch_op.add_column(sa.Column("pass_purchase_id", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("subscription_id", sa.Integer(), nullable=True))
        batch_op.create_foreign_key("fk_viewlogs_pass_id", "time_pass_purchases", ["pass_purchase_id"], ["id"], ondelete="SET NULL")
        batch_op.create_foreign_key("fk_viewlogs_sub_id", "subscriptions", ["subscription_id"], ["id"], ondelete="SET NULL")
    op.create_index("ix_view_logs_pass_purchase_id", "view_logs", ["pass_purchase_id"])
    op.create_index("ix_view_logs_subscription_id", "view_logs", ["subscription_id"])

    with op.batch_alter_table("time_pass_purchases", schema=None) as batch_op:
        batch_op.add_column(sa.Column("revenue_processed", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    with op.batch_alter_table("subscriptions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("revenue_processed", sa.Boolean(), nullable=False, server_default=sa.text("false")))

    op.execute(
        "INSERT INTO app_settings (key, value, description) VALUES ('review_max_chars', '100', 'Maximum characters per review text') "
        "ON CONFLICT (key) DO NOTHING"
    )


def downgrade() -> None:
    op.drop_column("subscriptions", "revenue_processed")
    op.drop_column("time_pass_purchases", "revenue_processed")

    op.drop_index("ix_view_logs_subscription_id", table_name="view_logs")
    op.drop_index("ix_view_logs_pass_purchase_id", table_name="view_logs")
    with op.batch_alter_table("view_logs", schema=None) as batch_op:
        batch_op.drop_constraint("fk_viewlogs_sub_id", type_="foreignkey")
        batch_op.drop_constraint("fk_viewlogs_pass_id", type_="foreignkey")
        batch_op.drop_column("subscription_id")
        batch_op.drop_column("pass_purchase_id")

    op.drop_table("reviews")
    op.drop_table("ratings")
    op.drop_table("revenue_transactions")
    op.drop_table("payouts")
    op.drop_table("revenue_split_rules")

    op.drop_index("ix_episodes_creator_id", table_name="episodes")
    with op.batch_alter_table("episodes", schema=None) as batch_op:
        batch_op.drop_constraint("fk_episodes_creator_id", type_="foreignkey")
        batch_op.drop_column("creator_id")
    op.drop_index("ix_series_creator_id", table_name="series")
    with op.batch_alter_table("series", schema=None) as batch_op:
        batch_op.drop_constraint("fk_series_creator_id", type_="foreignkey")
        batch_op.drop_column("creator_id")

    op.drop_table("creators")
