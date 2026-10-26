from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0007_series_free_episodes_override"
down_revision: Union[str, None] = "0006_loyalty_reward_unique_claims"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Allow series.free_episode_count to be NULL (indicating it inherits global default setting)
    op.alter_column(
        "series",
        "free_episode_count",
        existing_type=sa.Integer(),
        nullable=True,
        server_default=None,
    )


def downgrade() -> None:
    op.alter_column(
        "series",
        "free_episode_count",
        existing_type=sa.Integer(),
        nullable=False,
        server_default="3",
    )
