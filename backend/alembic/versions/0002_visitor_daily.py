"""지역별 방문자수 저장 테이블, users.email 보강.

데이터랩 방문자수는 원천이 약 75일 지연이라 한 번 받은 날짜는 바뀌지 않는다. 요청마다
전국분을 다시 받지 않도록 날짜 단위로 저장한다.

users.email 은 alembic 도입 전에 기동 시 ALTER 로 붙이던 컬럼이라, 그 코드로 한 번도
뜬 적 없는 DB 에는 아직 없을 수 있어 여기서 보강한다.

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-15
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT")

    if sa.inspect(op.get_bind()).has_table("visitor_daily"):
        return
    op.create_table(
        "visitor_daily",
        sa.Column("signgu_cd", sa.Text, primary_key=True),
        sa.Column("day", sa.Date, primary_key=True),
        sa.Column("signgu_nm", sa.Text),
        sa.Column("local", sa.Integer, nullable=False, server_default="0"),
        sa.Column("outsider", sa.Integer, nullable=False, server_default="0"),
        sa.Column("foreigner", sa.Integer, nullable=False, server_default="0"),
        sa.Column("total", sa.Integer, nullable=False, server_default="0"),
        sa.Column("fetched_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_visitor_day", "visitor_daily", ["day"])


def downgrade() -> None:
    op.drop_index("idx_visitor_day", table_name="visitor_daily")
    op.drop_table("visitor_daily")
