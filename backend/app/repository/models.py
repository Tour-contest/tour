from __future__ import annotations

from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    BigInteger, DateTime, Float, Identity, Index, Integer, Text, func, text,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.core.config import settings


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        Index("idx_user_social", "provider", "provider_uid", unique=True,
              postgresql_where=text("provider_uid IS NOT NULL")),
        Index("idx_user_login", "login_id", unique=True,
              postgresql_where=text("login_id IS NOT NULL")),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    provider: Mapped[str] = mapped_column(Text)
    provider_uid: Mapped[str | None] = mapped_column(Text)
    login_id: Mapped[str | None] = mapped_column(Text)
    password_hash: Mapped[str | None] = mapped_column(Text)
    nickname: Mapped[str | None] = mapped_column(Text)
    email: Mapped[str | None] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text, server_default="user")
    status: Mapped[str] = mapped_column(Text, server_default="active")
    fail_count: Mapped[int] = mapped_column(Integer, server_default="0")
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    __table_args__ = (Index("idx_refresh_user", "user_id"),)

    token_hash: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(Text)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[int] = mapped_column(Integer, server_default="0")
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class AreaCode(Base):
    __tablename__ = "area_codes"

    crowd_cd: Mapped[str] = mapped_column(Text, primary_key=True)
    tour_cd: Mapped[str | None] = mapped_column(Text)
    area_cd: Mapped[str] = mapped_column(Text)
    sido_nm: Mapped[str] = mapped_column(Text)
    signgu_nm: Mapped[str] = mapped_column(Text)
    aliases: Mapped[str] = mapped_column(Text, server_default="[]")
    has_crowd_data: Mapped[int | None] = mapped_column(Integer)


class AttractionNameMap(Base):
    __tablename__ = "attraction_name_map"

    signgu_cd: Mapped[str] = mapped_column(Text, primary_key=True)
    tats_nm: Mapped[str] = mapped_column(Text, primary_key=True)
    content_id: Mapped[str | None] = mapped_column(Text)
    matched_title: Mapped[str | None] = mapped_column(Text)
    match_method: Mapped[str | None] = mapped_column(Text)
    confidence: Mapped[float | None] = mapped_column(Float)
    image: Mapped[str | None] = mapped_column(Text)
    built_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class RecentAttraction(Base):
    __tablename__ = "recent_attractions"

    user_id: Mapped[str] = mapped_column(Text, primary_key=True)
    content_id: Mapped[str] = mapped_column(Text, primary_key=True)
    title: Mapped[str] = mapped_column(Text)
    signgu_cd: Mapped[str | None] = mapped_column(Text)
    signgu_nm: Mapped[str | None] = mapped_column(Text)
    last_level: Mapped[str | None] = mapped_column(Text)
    viewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class AttractionVector(Base):
    __tablename__ = "attraction_vectors"
    __table_args__ = (Index("idx_vec_area", "signgu_cd"),)

    content_id: Mapped[str] = mapped_column(Text, primary_key=True)
    signgu_cd: Mapped[str] = mapped_column(Text)
    title: Mapped[str | None] = mapped_column(Text)
    lcls1: Mapped[str | None] = mapped_column(Text)
    lcls2: Mapped[str | None] = mapped_column(Text)
    embedding: Mapped[list[float]] = mapped_column(Vector(settings.embedding_dim))
    built_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class ChatSession(Base):
    __tablename__ = "chat_sessions"
    __table_args__ = (
        Index("idx_sess_user", "user_id", text("last_active_at DESC")),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(Text)
    title: Mapped[str | None] = mapped_column(Text)
    summary: Mapped[str | None] = mapped_column(Text)
    summary_upto: Mapped[int] = mapped_column(BigInteger, server_default="0")
    resolved: Mapped[str] = mapped_column(Text, server_default="{}")
    status: Mapped[str] = mapped_column(Text, server_default="active")
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())
    last_active_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    __table_args__ = (Index("idx_msg_session", "session_id", "id"),)

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=False), primary_key=True)
    session_id: Mapped[str] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text)
    content: Mapped[str] = mapped_column(Text)
    tool_trace: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class ApiCallLog(Base):
    __tablename__ = "api_call_logs"
    __table_args__ = (
        Index("idx_call_at", text("called_at DESC")),
        Index("idx_call_provider", "provider", text("called_at DESC")),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=False), primary_key=True)
    session_id: Mapped[str | None] = mapped_column(Text)
    provider: Mapped[str] = mapped_column(Text)
    operation: Mapped[str] = mapped_column(Text)
    params: Mapped[str | None] = mapped_column(Text)
    status_code: Mapped[int | None] = mapped_column(Integer)
    result_code: Mapped[str | None] = mapped_column(Text)
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    cache_hit: Mapped[int] = mapped_column(Integer, server_default="0")
    called_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class LlmCallLog(Base):
    __tablename__ = "llm_call_logs"
    __table_args__ = (Index("idx_llm_at", text("called_at DESC")),)

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=False), primary_key=True)
    model: Mapped[str] = mapped_column(Text)
    purpose: Mapped[str] = mapped_column(Text)
    prompt_tokens: Mapped[int] = mapped_column(Integer, server_default="0")
    completion_tokens: Mapped[int] = mapped_column(Integer, server_default="0")
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(Text, server_default="ok")
    called_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now())


class CategoryCode(Base):
    __tablename__ = "category_codes"

    code: Mapped[str] = mapped_column(Text, primary_key=True)
    name: Mapped[str] = mapped_column(Text)
    level: Mapped[int] = mapped_column(Integer, server_default="1")
