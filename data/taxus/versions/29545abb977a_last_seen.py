"""last-seen

Revision ID: 29545abb977a
Revises:
Create Date: 2017-08-13 05:59:48.847193

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '29545abb977a'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('ids_lctr', sa.Column('last_seen', sa.DateTime, index=True,
        nullable=True))

def downgrade():
    op.drop_column('ids_lctr', 'last_seen')

