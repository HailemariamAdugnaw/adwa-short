from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004_creator_portal_fields"
down_revision: Union[str, None] = "0003_download_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("creators", sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, unique=True))
    op.add_column("creators", sa.Column("bio", sa.Text(), nullable=True))
    op.add_column("creators", sa.Column("mobile_money_number", sa.String(length=64), nullable=True))
    op.add_column("creators", sa.Column("tax_id", sa.String(length=64), nullable=True))
    op.create_index("ix_creators_user_id", "creators", ["user_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_creators_user_id", table_name="creators")
    op.drop_column("creators", "tax_id")
    op.drop_column("creators", "mobile_money_number")
    op.drop_column("creators", "bio")
    op.drop_column("creators", "user_id")
