from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0006_loyalty_reward_unique_claims"
down_revision: Union[str, None] = "0005_ad_configuration_and_impressions"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add reward_id column to loyalty_reward_grants
    op.add_column(
        "loyalty_reward_grants",
        sa.Column(
            "reward_id",
            sa.Integer(),
            sa.ForeignKey("loyalty_reward_configs.id", ondelete="CASCADE"),
            nullable=True,
        ),
    )
    op.create_index("ix_lrg_reward_id", "loyalty_reward_grants", ["reward_id"])

    # 2. Backfill existing tier reward grants with active loyalty_reward_configs.id
    # and deduplicate historical test claims to ensure uniqueness
    conn = op.get_bind()
    conn.execute(
        sa.text(
            """
            UPDATE loyalty_reward_grants
            SET reward_id = (SELECT id FROM loyalty_reward_configs LIMIT 1)
            WHERE details IS NOT NULL AND details::text LIKE '%Loyalty Tier Reward%';
            """
        )
    )
    conn.execute(
        sa.text(
            """
            DELETE FROM loyalty_reward_grants
            WHERE reward_id IS NOT NULL
              AND id NOT IN (
                SELECT MIN(id) FROM loyalty_reward_grants WHERE reward_id IS NOT NULL GROUP BY user_id, reward_id
              );
            """
        )
    )

    # 3. Create unique constraint (user_id, reward_id)
    op.create_unique_constraint(
        "uq_user_loyalty_reward",
        "loyalty_reward_grants",
        ["user_id", "reward_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_user_loyalty_reward", "loyalty_reward_grants", type_="unique")
    op.drop_index("ix_lrg_reward_id", table_name="loyalty_reward_grants")
    op.drop_column("loyalty_reward_grants", "reward_id")
