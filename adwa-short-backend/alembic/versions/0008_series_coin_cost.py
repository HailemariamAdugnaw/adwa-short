from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0008_series_coin_cost"
down_revision: Union[str, None] = "0007_series_free_episodes_override"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add optional coin_cost override to series table
    op.add_column("series", sa.Column("coin_cost", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("series", "coin_cost")
