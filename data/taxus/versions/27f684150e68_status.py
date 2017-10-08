"""status

Revision ID: 27f684150e68
Revises: 29545abb977a
Create Date: 2017-08-13 07:37:23.406596

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '27f684150e68'
down_revision = '29545abb977a'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('ids_lctr', sa.Column('status', sa.Integer, index=True,
        nullable=True))

def downgrade():
    op.drop_column('ids_lctr', 'status')

