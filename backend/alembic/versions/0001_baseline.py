"""기준 스키마. alembic 도입 시점의 테이블 전부.

이미 이 테이블들이 있는 DB(운영 서버)에는 실행하지 말고 `alembic stamp 0001` 로
버전만 찍는다. 새 DB 에서는 `alembic upgrade head` 로 만든다.

Revision ID: 0001
Revises:
Create Date: 2026-09-15
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector

from app.core.config import settings

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def ts(name: str, *, default_now: bool = False, nullable: bool = True) -> sa.Column:
    return sa.Column(
        name, sa.DateTime(timezone=True), nullable=nullable,
        server_default=sa.func.now() if default_now else None,
    )


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "users",
        sa.Column("id", sa.Text, primary_key=True),
        sa.Column("provider", sa.Text, nullable=False),
        sa.Column("provider_uid", sa.Text),
        sa.Column("login_id", sa.Text),
        sa.Column("password_hash", sa.Text),
        sa.Column("nickname", sa.Text),
        sa.Column("email", sa.Text),
        sa.Column("role", sa.Text, nullable=False, server_default="user"),
        sa.Column("status", sa.Text, nullable=False, server_default="active"),
        sa.Column("fail_count", sa.Integer, nullable=False, server_default="0"),
        ts("locked_until"),
        ts("created_at", default_now=True),
        ts("last_login_at"),
    )
    op.create_index("idx_user_social", "users", ["provider", "provider_uid"], unique=True,
                    postgresql_where=sa.text("provider_uid IS NOT NULL"))
    op.create_index("idx_user_login", "users", ["login_id"], unique=True,
                    postgresql_where=sa.text("login_id IS NOT NULL"))

    op.create_table(
        "refresh_tokens",
        sa.Column("token_hash", sa.Text, primary_key=True),
        sa.Column("user_id", sa.Text, nullable=False),
        ts("expires_at", nullable=False),
        sa.Column("revoked", sa.Integer, nullable=False, server_default="0"),
        ts("created_at", default_now=True),
    )
    op.create_index("idx_refresh_user", "refresh_tokens", ["user_id"])

    op.create_table(
        "area_codes",
        sa.Column("crowd_cd", sa.Text, primary_key=True),
        sa.Column("tour_cd", sa.Text),
        sa.Column("area_cd", sa.Text, nullable=False),
        sa.Column("sido_nm", sa.Text, nullable=False),
        sa.Column("signgu_nm", sa.Text, nullable=False),
        sa.Column("aliases", sa.Text, nullable=False, server_default="[]"),
        sa.Column("has_crowd_data", sa.Integer),
    )

    op.create_table(
        "attraction_name_map",
        sa.Column("signgu_cd", sa.Text, primary_key=True),
        sa.Column("tats_nm", sa.Text, primary_key=True),
        sa.Column("content_id", sa.Text),
        sa.Column("matched_title", sa.Text),
        sa.Column("match_method", sa.Text),
        sa.Column("confidence", sa.Float),
        sa.Column("image", sa.Text),
        ts("built_at", default_now=True),
    )

    op.create_table(
        "recent_attractions",
        sa.Column("user_id", sa.Text, primary_key=True),
        sa.Column("content_id", sa.Text, primary_key=True),
        sa.Column("title", sa.Text, nullable=False),
        sa.Column("signgu_cd", sa.Text),
        sa.Column("signgu_nm", sa.Text),
        sa.Column("last_level", sa.Text),
        ts("viewed_at", default_now=True),
    )

    op.create_table(
        "attraction_vectors",
        sa.Column("content_id", sa.Text, primary_key=True),
        sa.Column("signgu_cd", sa.Text, nullable=False),
        sa.Column("title", sa.Text),
        sa.Column("lcls1", sa.Text),
        sa.Column("lcls2", sa.Text),
        sa.Column("embedding", Vector(settings.embedding_dim), nullable=False),
        ts("built_at", default_now=True),
    )
    op.create_index("idx_vec_area", "attraction_vectors", ["signgu_cd"])

    op.create_table(
        "chat_sessions",
        sa.Column("id", sa.Text, primary_key=True),
        sa.Column("user_id", sa.Text, nullable=False),
        sa.Column("title", sa.Text),
        sa.Column("summary", sa.Text),
        sa.Column("summary_upto", sa.BigInteger, nullable=False, server_default="0"),
        sa.Column("resolved", sa.Text, nullable=False, server_default="{}"),
        sa.Column("status", sa.Text, nullable=False, server_default="active"),
        ts("created_at", default_now=True),
        ts("last_active_at", default_now=True),
    )
    op.create_index("idx_sess_user", "chat_sessions", ["user_id", sa.text("last_active_at DESC")])

    op.create_table(
        "chat_messages",
        sa.Column("id", sa.BigInteger, sa.Identity(always=False), primary_key=True),
        sa.Column("session_id", sa.Text, nullable=False),
        sa.Column("role", sa.Text, nullable=False),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("tool_trace", sa.Text),
        ts("created_at", default_now=True),
    )
    op.create_index("idx_msg_session", "chat_messages", ["session_id", "id"])

    op.create_table(
        "api_call_logs",
        sa.Column("id", sa.BigInteger, sa.Identity(always=False), primary_key=True),
        sa.Column("session_id", sa.Text),
        sa.Column("provider", sa.Text, nullable=False),
        sa.Column("operation", sa.Text, nullable=False),
        sa.Column("params", sa.Text),
        sa.Column("status_code", sa.Integer),
        sa.Column("result_code", sa.Text),
        sa.Column("latency_ms", sa.Integer),
        sa.Column("cache_hit", sa.Integer, nullable=False, server_default="0"),
        ts("called_at", default_now=True),
    )
    op.create_index("idx_call_at", "api_call_logs", [sa.text("called_at DESC")])
    op.create_index("idx_call_provider", "api_call_logs", ["provider", sa.text("called_at DESC")])

    op.create_table(
        "llm_call_logs",
        sa.Column("id", sa.BigInteger, sa.Identity(always=False), primary_key=True),
        sa.Column("model", sa.Text, nullable=False),
        sa.Column("purpose", sa.Text, nullable=False),
        sa.Column("prompt_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("completion_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("latency_ms", sa.Integer),
        sa.Column("status", sa.Text, nullable=False, server_default="ok"),
        ts("called_at", default_now=True),
    )
    op.create_index("idx_llm_at", "llm_call_logs", [sa.text("called_at DESC")])

    op.create_table(
        "category_codes",
        sa.Column("code", sa.Text, primary_key=True),
        sa.Column("name", sa.Text, nullable=False),
        sa.Column("level", sa.Integer, nullable=False, server_default="1"),
    )


def downgrade() -> None:
    for t in (
        "category_codes", "llm_call_logs", "api_call_logs", "chat_messages", "chat_sessions",
        "attraction_vectors", "recent_attractions", "attraction_name_map", "area_codes",
        "refresh_tokens", "users",
    ):
        op.drop_table(t)
