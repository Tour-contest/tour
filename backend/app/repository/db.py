from __future__ import annotations

import asyncio
import json
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import date as _date
from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

import logging

from sqlalchemy import (
    Date, Float, case, cast, delete, exists, func, or_, select, text, update,
)
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import (
    AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine,
)
from sqlalchemy.orm import aliased

from app.core.config import settings
from app.repository.models import (
    ApiCallLog, AreaCode, AttractionNameMap, AttractionVector, Base,
    CategoryCode, ChatMessage, ChatSession, LlmCallLog, RecentAttraction,
    RefreshToken, User,
)

log = logging.getLogger("tour.db")

try:
    _TZ = ZoneInfo(settings.report_tz)
except Exception:
    _TZ = datetime.now().astimezone().tzinfo or timezone.utc


def url() -> str:
    u = settings.database_url
    return u if "+asyncpg" in u else u.replace("postgresql://", "postgresql+asyncpg://", 1)


_engines: dict[int, AsyncEngine] = {}
_makers: dict[int, async_sessionmaker[AsyncSession]] = {}


def maker() -> async_sessionmaker[AsyncSession]:
    key = id(asyncio.get_running_loop())
    if key not in _makers:
        engine = create_async_engine(url(), pool_size=10, max_overflow=5)
        _engines[key] = engine
        _makers[key] = async_sessionmaker(engine, expire_on_commit=False)
    return _makers[key]


@asynccontextmanager
async def session() -> AsyncIterator[AsyncSession]:
    async with maker()() as s:
        yield s


async def close() -> None:
    key = id(asyncio.get_running_loop())
    _makers.pop(key, None)
    engine = _engines.pop(key, None)
    if engine is not None:
        await engine.dispose()


def iso(v):
    if isinstance(v, datetime):
        return v.astimezone(_TZ).isoformat()
    if isinstance(v, _date):
        return v.isoformat()
    return v


def row(obj) -> dict:
    return {c.name: iso(getattr(obj, c.name)) for c in obj.__table__.columns}


def ts(v) -> datetime | None:
    if v is None or isinstance(v, datetime):
        return v
    dt = datetime.fromisoformat(str(v))
    return dt if dt.tzinfo else dt.replace(tzinfo=_TZ)


def day_bounds(day: str) -> tuple[datetime, datetime]:
    start = datetime.combine(_date.fromisoformat(day), time.min, tzinfo=_TZ)
    return start, start + timedelta(days=1)


def today() -> str:
    return datetime.now(_TZ).date().isoformat()


async def drop_vectors_if_dim_changed(conn) -> None:
    dim = (await conn.execute(text(
        "SELECT a.atttypmod FROM pg_attribute a"
        " JOIN pg_class c ON c.oid = a.attrelid"
        " WHERE c.relname = 'attraction_vectors' AND a.attname = 'embedding'"
    ))).scalar()
    if dim is not None and dim != settings.embedding_dim:
        log.warning(
            "임베딩 차원 변경(%s -> %s)으로 attraction_vectors 재생성, jobs.run vectors 재실행 필요",
            dim, settings.embedding_dim,
        )
        await conn.execute(text("DROP TABLE attraction_vectors"))


async def init() -> None:
    key = id(asyncio.get_running_loop())
    if key not in _engines:
        maker()
    async with _engines[key].begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        await drop_vectors_if_dim_changed(conn)
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT"))
    async with session() as s:
        await s.execute(
            delete(ChatMessage).where(
                ChatMessage.session_id.notin_(select(ChatSession.id))
            )
        )
        await s.commit()


_USER_LOOKUP_COLS = {"id", "login_id", "provider", "provider_uid"}


async def find_user(**where) -> dict | None:
    if not where or set(where) - _USER_LOOKUP_COLS:
        raise ValueError(f"허용되지 않은 조회 컬럼: {set(where) - _USER_LOOKUP_COLS}")
    async with session() as s:
        u = (await s.execute(select(User).filter_by(**where))).scalar_one_or_none()
        return row(u) if u else None


async def create_user(user: dict) -> dict:
    async with session() as s:
        s.add(User(
            id=user["id"],
            provider=user["provider"],
            provider_uid=user.get("provider_uid"),
            login_id=user.get("login_id"),
            password_hash=user.get("password_hash"),
            nickname=user.get("nickname"),
            email=user.get("email"),
            role=user.get("role", "user"),
        ))
        await s.commit()
    return await find_user(id=user["id"])


async def set_user_email(user_id: str, email: str) -> None:
    async with session() as s:
        await s.execute(update(User).where(User.id == user_id).values(email=email))
        await s.commit()


async def touch_login(user_id: str, ok: bool, lock_until: str | None = None) -> None:
    async with session() as s:
        if ok:
            await s.execute(
                update(User).where(User.id == user_id)
                .values(last_login_at=func.now(), fail_count=0, locked_until=None)
            )
        else:
            await s.execute(
                update(User).where(User.id == user_id)
                .values(fail_count=User.fail_count + 1, locked_until=ts(lock_until))
            )
        await s.commit()


async def list_users(q: str = "", limit: int = 50, offset: int = 0) -> tuple[list[dict], int]:
    where = []
    if q:
        where.append(or_(User.nickname.ilike(f"%{q}%"), User.login_id.ilike(f"%{q}%")))
    async with session() as s:
        total = (await s.execute(
            select(func.count()).select_from(User).where(*where)
        )).scalar_one()
        users = (await s.execute(
            select(User).where(*where)
            .order_by(User.created_at.desc()).limit(limit).offset(offset)
        )).scalars().all()
        rows = [{k: v for k, v in row(u).items() if k != "password_hash"} for u in users]
    return rows, total


async def set_user_status(user_id: str, status: str) -> None:
    async with session() as s:
        await s.execute(update(User).where(User.id == user_id).values(status=status))
        await s.commit()


async def delete_user(user_id: str) -> None:
    async with session() as s:
        await s.execute(delete(RefreshToken).where(RefreshToken.user_id == user_id))
        await s.execute(delete(RecentAttraction).where(RecentAttraction.user_id == user_id))
        await s.execute(
            delete(ChatMessage).where(
                ChatMessage.session_id.in_(
                    select(ChatSession.id).where(ChatSession.user_id == user_id)
                )
            )
        )
        await s.execute(delete(ChatSession).where(ChatSession.user_id == user_id))
        await s.execute(delete(User).where(User.id == user_id))
        await s.commit()


async def save_refresh(token_hash: str, user_id: str, expires_at: str) -> None:
    async with session() as s:
        ins = pg_insert(RefreshToken).values(
            token_hash=token_hash, user_id=user_id, expires_at=ts(expires_at)
        )
        await s.execute(ins.on_conflict_do_update(
            index_elements=["token_hash"],
            set_={"user_id": ins.excluded.user_id, "expires_at": ins.excluded.expires_at,
                  "revoked": 0, "created_at": func.now()},
        ))
        await s.commit()


async def get_refresh(token_hash: str) -> dict | None:
    async with session() as s:
        t = (await s.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        )).scalar_one_or_none()
        return row(t) if t else None


async def revoke_refresh(token_hash: str) -> bool:
    async with session() as s:
        res = await s.execute(
            update(RefreshToken)
            .where(RefreshToken.token_hash == token_hash, RefreshToken.revoked == 0)
            .values(revoked=1)
        )
        await s.commit()
        return res.rowcount == 1


async def revoke_all_refresh(user_id: str) -> None:
    async with session() as s:
        await s.execute(
            update(RefreshToken).where(RefreshToken.user_id == user_id).values(revoked=1)
        )
        await s.commit()


async def upsert_areas(rows: list[dict]) -> None:
    ins = pg_insert(AreaCode)
    stmt = ins.on_conflict_do_update(
        index_elements=["crowd_cd"],
        set_={"tour_cd": ins.excluded.tour_cd, "sido_nm": ins.excluded.sido_nm,
              "signgu_nm": ins.excluded.signgu_nm, "aliases": ins.excluded.aliases},
    )
    async with session() as s:
        await s.execute(stmt, [
            {
                "crowd_cd": r["crowd_cd"],
                "tour_cd": r.get("tour_cd"),
                "area_cd": r["area_cd"],
                "sido_nm": r["sido_nm"],
                "signgu_nm": r["signgu_nm"],
                "aliases": json.dumps(r["aliases"], ensure_ascii=False),
            }
            for r in rows
        ])
        await s.commit()


def area_dict(a: AreaCode) -> dict:
    return {
        "crowd_cd": a.crowd_cd,
        "tour_cd": a.tour_cd or a.crowd_cd,
        "signgu_cd": a.crowd_cd,
        "area_cd": a.area_cd,
        "sido_nm": a.sido_nm,
        "signgu_nm": a.signgu_nm,
        "aliases": json.loads(a.aliases),
        "label": a.sido_nm if a.signgu_nm == a.sido_nm else f"{a.sido_nm} {a.signgu_nm}",
        "has_crowd_data": None if a.has_crowd_data is None else bool(a.has_crowd_data),
    }


async def all_areas() -> list[dict]:
    async with session() as s:
        rows = (await s.execute(select(AreaCode).order_by(AreaCode.crowd_cd))).scalars()
        return [area_dict(a) for a in rows]


async def area_count() -> int:
    async with session() as s:
        return (await s.execute(select(func.count()).select_from(AreaCode))).scalar_one()


async def child_areas(signgu_nm: str, area_cd: str | None = None) -> list[dict]:
    cond = (
        AreaCode.area_cd == area_cd
        if area_cd
        else AreaCode.signgu_nm.like(f"{signgu_nm} %")
    )
    async with session() as s:
        rows = (await s.execute(
            select(AreaCode)
            .where(cond, AreaCode.signgu_nm != signgu_nm)
            .order_by(AreaCode.crowd_cd)
        )).scalars()
        return [area_dict(a) for a in rows]


async def set_crowd_flag(crowd_cd: str, has: bool) -> None:
    async with session() as s:
        await s.execute(
            update(AreaCode).where(AreaCode.crowd_cd == crowd_cd)
            .values(has_crowd_data=1 if has else 0)
        )
        await s.commit()


async def promote_parent_crowd_flags() -> None:
    c = aliased(AreaCode)
    async with session() as s:
        await s.execute(
            update(AreaCode)
            .where(
                AreaCode.has_crowd_data == 0,
                exists(select(1).where(
                    c.signgu_nm.like(AreaCode.signgu_nm + " %"),
                    c.has_crowd_data == 1,
                )),
            )
            .values(has_crowd_data=1)
        )
        await s.execute(
            update(AreaCode)
            .where(
                AreaCode.signgu_nm == AreaCode.sido_nm,
                or_(AreaCode.has_crowd_data == 0, AreaCode.has_crowd_data.is_(None)),
                exists(select(1).where(
                    c.area_cd == AreaCode.area_cd,
                    c.signgu_nm != AreaCode.signgu_nm,
                    c.has_crowd_data == 1,
                )),
            )
            .values(has_crowd_data=1)
        )
        await s.commit()


async def crowd_flag_stats() -> dict:
    async with session() as s:
        row = (await s.execute(
            select(
                func.count().label("checked"),
                func.sum(case((AreaCode.has_crowd_data == 1, 1), else_=0)).label("w"),
            ).where(AreaCode.has_crowd_data.isnot(None))
        )).one()
        return {"checked": row.checked or 0, "with": row.w or 0}


async def get_area(code: str) -> dict | None:
    async with session() as s:
        a = (await s.execute(
            select(AreaCode).where(AreaCode.crowd_cd == code)
        )).scalar_one_or_none()
        if a is None:
            a = (await s.execute(
                select(AreaCode).where(AreaCode.tour_cd == code)
            )).scalars().first()
        return area_dict(a) if a else None


async def areas_by_code(codes: set[str] | list[str]) -> dict[str, dict]:
    codes = [c for c in codes if c]
    if not codes:
        return {}
    async with session() as s:
        rows = (await s.execute(
            select(AreaCode).where(
                or_(AreaCode.crowd_cd.in_(codes), AreaCode.tour_cd.in_(codes))
            )
        )).scalars()
    out: dict[str, dict] = {}
    for a in rows:
        d = area_dict(a)
        out.setdefault(d["crowd_cd"], d)
        if a.tour_cd:
            out.setdefault(a.tour_cd, d)
    return out


async def get_mapping(signgu_cd: str) -> dict[str, dict]:
    async with session() as s:
        rows = (await s.execute(
            select(AttractionNameMap).where(AttractionNameMap.signgu_cd == signgu_cd)
        )).scalars()
        return {
            m.tats_nm: {
                "content_id": m.content_id,
                "matched_title": m.matched_title,
                "match_method": m.match_method,
                "confidence": m.confidence,
                "image": m.image,
            }
            for m in rows
        }


async def put_mapping(signgu_cd: str, rows: list[dict]) -> None:
    if not rows:
        return
    ins = pg_insert(AttractionNameMap)
    stmt = ins.on_conflict_do_update(
        index_elements=["signgu_cd", "tats_nm"],
        set_={"content_id": ins.excluded.content_id,
              "matched_title": ins.excluded.matched_title,
              "match_method": ins.excluded.match_method,
              "confidence": ins.excluded.confidence,
              "image": ins.excluded.image},
    )
    async with session() as s:
        await s.execute(stmt, [
            {
                "signgu_cd": signgu_cd,
                "tats_nm": r["tats_nm"],
                "content_id": r.get("content_id"),
                "matched_title": r.get("matched_title"),
                "match_method": r.get("match_method"),
                "confidence": r.get("confidence"),
                "image": r.get("image"),
            }
            for r in rows
        ])
        await s.commit()


async def mapping_area(content_id: str) -> str | None:
    async with session() as s:
        return (await s.execute(
            select(AttractionNameMap.signgu_cd)
            .where(AttractionNameMap.content_id == content_id).limit(1)
        )).scalar_one_or_none()


async def mapping_stats() -> dict:
    async with session() as s:
        row = (await s.execute(
            select(
                func.count().label("total"),
                func.sum(case((AttractionNameMap.content_id.isnot(None), 1), else_=0)
                         ).label("matched"),
                func.count(func.distinct(AttractionNameMap.signgu_cd)).label("areas"),
            )
        )).one()
        return {"total": row.total or 0, "matched": row.matched or 0, "areas": row.areas or 0}


async def put_vectors(rows: list[dict]) -> None:
    if not rows:
        return
    ins = pg_insert(AttractionVector)
    stmt = ins.on_conflict_do_update(
        index_elements=["content_id"],
        set_={"embedding": ins.excluded.embedding, "built_at": func.now()},
    )
    async with session() as s:
        await s.execute(stmt, [
            {
                "content_id": r["content_id"],
                "signgu_cd": r["signgu_cd"],
                "title": r.get("title"),
                "lcls1": r.get("lcls1"),
                "lcls2": r.get("lcls2"),
                "embedding": r["embedding"],
            }
            for r in rows
        ])
        await s.commit()


async def vector_ids(content_ids: list[str]) -> set[str]:
    if not content_ids:
        return set()
    async with session() as s:
        rows = (await s.execute(
            select(AttractionVector.content_id)
            .where(AttractionVector.content_id.in_(content_ids))
        )).scalars()
        return set(rows)


async def similar_vectors(
    content_id: str, signgu_cd: str, *, limit: int = 10, min_similarity: float = 0.0,
    exclude: set[str] | None = None,
) -> list[dict]:
    async with session() as s:
        base = (await s.execute(
            select(AttractionVector.embedding)
            .where(AttractionVector.content_id == content_id)
        )).scalar_one_or_none()
        if base is None:
            return []

        sim = (1 - AttractionVector.embedding.cosine_distance(base)).label("similarity")
        stmt = (
            select(AttractionVector.content_id, AttractionVector.title,
                   AttractionVector.lcls1, AttractionVector.lcls2, sim)
            .where(AttractionVector.signgu_cd == signgu_cd,
                   AttractionVector.content_id != content_id)
            .order_by(AttractionVector.embedding.cosine_distance(base))
            .limit(limit)
        )
        if exclude:
            stmt = stmt.where(AttractionVector.content_id.notin_(list(exclude)))
        rows = (await s.execute(stmt)).all()

    return [
        {"content_id": r.content_id, "title": r.title, "lcls1": r.lcls1,
         "lcls2": r.lcls2, "similarity": round(float(r.similarity), 3)}
        for r in rows
        if r.similarity is not None and float(r.similarity) >= min_similarity
    ]


async def vector_stats() -> dict:
    async with session() as s:
        row = (await s.execute(
            select(func.count().label("n"),
                   func.count(func.distinct(AttractionVector.signgu_cd)).label("areas"))
        )).one()
        return {"vectors": row.n or 0, "areas": row.areas or 0}


async def touch_recent(user_id: str, item: dict, limit: int) -> None:
    async with session() as s:
        ins = pg_insert(RecentAttraction).values(
            user_id=user_id,
            content_id=item["content_id"],
            title=item["title"],
            signgu_cd=item.get("signgu_cd"),
            signgu_nm=item.get("signgu_nm"),
            last_level=item.get("last_level"),
            viewed_at=func.now(),
        )
        await s.execute(ins.on_conflict_do_update(
            index_elements=["user_id", "content_id"],
            set_={"last_level": ins.excluded.last_level, "viewed_at": func.now()},
        ))
        keep = (
            select(RecentAttraction.content_id)
            .where(RecentAttraction.user_id == user_id)
            .order_by(RecentAttraction.viewed_at.desc())
            .limit(limit)
        )
        await s.execute(
            delete(RecentAttraction).where(
                RecentAttraction.user_id == user_id,
                RecentAttraction.content_id.notin_(keep),
            )
        )
        await s.commit()


async def list_recent(user_id: str) -> list[dict]:
    async with session() as s:
        rows = (await s.execute(
            select(RecentAttraction)
            .where(RecentAttraction.user_id == user_id)
            .order_by(RecentAttraction.viewed_at.desc())
        )).scalars()
        return [row(r) for r in rows]


async def clear_recent(user_id: str) -> None:
    async with session() as s:
        await s.execute(delete(RecentAttraction).where(RecentAttraction.user_id == user_id))
        await s.commit()


async def ensure_session(session_id: str, user_id: str, first_message: str = "") -> dict:
    title = (first_message or "새 대화").strip()[:40]
    async with session() as s:
        created = (await s.execute(
            pg_insert(ChatSession)
            .values(id=session_id, user_id=user_id, title=title)
            .on_conflict_do_nothing(index_elements=["id"])
            .returning(ChatSession)
        )).scalar_one_or_none()
        await s.commit()
        if created is None:
            created = (await s.execute(
                select(ChatSession).where(ChatSession.id == session_id)
            )).scalar_one()
    d = row(created)
    d["resolved"] = json.loads(d.get("resolved") or "{}")
    return d


async def touch_session(session_id: str) -> None:
    async with session() as s:
        await s.execute(
            update(ChatSession).where(ChatSession.id == session_id)
            .values(last_active_at=func.now())
        )
        await s.commit()


async def save_resolved(session_id: str, resolved: dict) -> None:
    async with session() as s:
        await s.execute(
            update(ChatSession).where(ChatSession.id == session_id)
            .values(resolved=json.dumps(resolved, ensure_ascii=False))
        )
        await s.commit()


async def save_summary(session_id: str, summary: str, upto: int = 0) -> None:
    async with session() as s:
        await s.execute(
            update(ChatSession).where(ChatSession.id == session_id)
            .values(summary=summary, summary_upto=upto)
        )
        await s.commit()


async def list_sessions(
    user_id: str, limit: int = 30, offset: int = 0
) -> tuple[list[dict], int]:
    n = (
        select(func.count())
        .where(ChatMessage.session_id == ChatSession.id)
        .scalar_subquery()
    )
    mine = (ChatSession.user_id == user_id, ChatSession.status == "active")
    async with session() as s:
        total = (await s.execute(
            select(func.count()).select_from(ChatSession).where(*mine)
        )).scalar_one()
        rows = await s.execute(
            select(ChatSession, n.label("n")).where(*mine)
            .order_by(ChatSession.last_active_at.desc())
            .limit(limit).offset(offset)
        )
        items = [
            {
                "id": sess.id,
                "title": sess.title,
                "messages": cnt,
                "last_active_at": iso(sess.last_active_at),
            }
            for sess, cnt in rows
        ]
    return items, total


async def get_session(session_id: str) -> dict | None:
    async with session() as s:
        sess = (await s.execute(
            select(ChatSession).where(ChatSession.id == session_id)
        )).scalar_one_or_none()
        if sess is None:
            return None
        d = row(sess)
        d["resolved"] = json.loads(d.get("resolved") or "{}")
        return d


async def delete_session(session_id: str) -> None:
    async with session() as s:
        await s.execute(delete(ChatMessage).where(ChatMessage.session_id == session_id))
        await s.execute(delete(ChatSession).where(ChatSession.id == session_id))
        await s.commit()


async def prune_sessions(user_id: str, keep: int = 30) -> None:
    async with session() as s:
        recent = (
            select(ChatSession.id)
            .where(ChatSession.user_id == user_id)
            .order_by(ChatSession.last_active_at.desc())
            .limit(keep)
        )
        ids = list((await s.execute(
            select(ChatSession.id)
            .where(ChatSession.user_id == user_id, ChatSession.id.notin_(recent))
        )).scalars())
        if not ids:
            return
        await s.execute(delete(ChatMessage).where(ChatMessage.session_id.in_(ids)))
        await s.execute(delete(ChatSession).where(ChatSession.id.in_(ids)))
        await s.commit()


async def add_message(session_id: str, role: str, content: str,
                      tool_trace: list | None = None) -> None:
    async with session() as s:
        s.add(ChatMessage(
            session_id=session_id, role=role, content=content,
            tool_trace=json.dumps(tool_trace or [], ensure_ascii=False),
        ))
        await s.commit()


async def add_call_logs(rows: list[dict]) -> None:
    if not rows:
        return
    async with session() as s:
        s.add_all([
            ApiCallLog(
                session_id=r.get("session_id"),
                provider=r["provider"],
                operation=r["operation"],
                params=json.dumps(r.get("params") or {}, ensure_ascii=False),
                status_code=r.get("status_code"),
                result_code=r.get("result_code"),
                latency_ms=r.get("latency_ms"),
                cache_hit=1 if r.get("cache_hit") else 0,
                called_at=ts(r.get("called_at")) or datetime.now(timezone.utc),
            )
            for r in rows
        ])
        await s.commit()


async def call_logs(limit: int = 100, provider: str | None = None) -> list[dict]:
    stmt = select(ApiCallLog).order_by(ApiCallLog.id.desc()).limit(limit)
    if provider:
        stmt = stmt.where(ApiCallLog.provider == provider)
    async with session() as s:
        rows = (await s.execute(stmt)).scalars()
        return [row(r) for r in rows]


async def add_llm_log(row: dict) -> None:
    async with session() as s:
        s.add(LlmCallLog(
            model=row["model"],
            purpose=row["purpose"],
            prompt_tokens=row.get("prompt_tokens", 0),
            completion_tokens=row.get("completion_tokens", 0),
            latency_ms=row.get("latency_ms"),
            status=row.get("status", "ok"),
        ))
        await s.commit()


def local_day(col):
    return cast(func.timezone(str(_TZ), col), Date)


async def llm_daily(days: int = 7) -> list[dict]:
    d = local_day(LlmCallLog.called_at).label("d")
    async with session() as s:
        rows = (await s.execute(
            select(d, func.sum(LlmCallLog.prompt_tokens).label("pt"),
                   func.sum(LlmCallLog.completion_tokens).label("ct"),
                   func.count().label("n"))
            .group_by(d).order_by(d.desc()).limit(days)
        )).all()
    out = [
        {"date": iso(r.d), "prompt": r.pt or 0, "completion": r.ct or 0, "calls": r.n}
        for r in rows
    ]
    out.reverse()
    return out


async def llm_summary(day: str) -> dict:
    start, end = day_bounds(day)
    in_day = (LlmCallLog.called_at >= start, LlmCallLog.called_at < end)
    async with session() as s:
        r = (await s.execute(
            select(
                func.count().label("n"),
                func.sum(LlmCallLog.prompt_tokens).label("pt"),
                func.sum(LlmCallLog.completion_tokens).label("ct"),
                cast(func.avg(case((LlmCallLog.status == "ok", LlmCallLog.latency_ms))),
                     Float).label("ms"),
                func.sum(case((LlmCallLog.status == "rate_limited", 1), else_=0)
                         ).label("limited"),
                func.sum(case((LlmCallLog.status.notin_(["ok", "rate_limited"]), 1),
                              else_=0)).label("err"),
            ).where(*in_day)
        )).one()
        rows = (await s.execute(
            select(LlmCallLog.purpose, func.count().label("n"),
                   func.sum(LlmCallLog.prompt_tokens + LlmCallLog.completion_tokens
                            ).label("t"))
            .where(*in_day).group_by(LlmCallLog.purpose).order_by(func.sum(
                LlmCallLog.prompt_tokens + LlmCallLog.completion_tokens).desc())
        )).all()
    return {
        "calls": r.n or 0,
        "prompt_tokens": r.pt or 0,
        "completion_tokens": r.ct or 0,
        "avg_latency_ms": round(r.ms) if r.ms else 0,
        "rate_limited": r.limited or 0,
        "errors": r.err or 0,
        "by_purpose": [
            {"purpose": p.purpose, "calls": p.n, "tokens": p.t or 0} for p in rows
        ],
    }


async def call_daily(days: int = 7) -> list[dict]:
    d = local_day(ApiCallLog.called_at).label("d")
    async with session() as s:
        rows = (await s.execute(
            select(d,
                   func.sum(case((ApiCallLog.cache_hit == 0, 1), else_=0)).label("real"),
                   func.sum(case((ApiCallLog.cache_hit == 1, 1), else_=0)).label("cached"))
            .group_by(d).order_by(d.desc()).limit(days)
        )).all()
    out = [
        {"date": iso(r.d), "real": r.real or 0, "cached": r.cached or 0} for r in rows
    ]
    out.reverse()
    return out


async def call_summary(day: str, provider: str | None = None) -> dict:
    start, end = day_bounds(day)
    cond = [ApiCallLog.called_at >= start, ApiCallLog.called_at < end]
    if provider:
        cond.append(ApiCallLog.provider == provider)
    err = case((or_(ApiCallLog.result_code.is_(None),
                    ApiCallLog.result_code.notin_(["0000", "ok"])), 1), else_=0)
    async with session() as s:
        rows = (await s.execute(
            select(ApiCallLog.operation, func.count().label("n"),
                   func.sum(err).label("err"),
                   cast(func.avg(ApiCallLog.latency_ms), Float).label("ms"))
            .where(ApiCallLog.cache_hit == 0, *cond)
            .group_by(ApiCallLog.operation)
        )).all()
        cached = (await s.execute(
            select(func.count()).where(ApiCallLog.cache_hit == 1, *cond)
        )).scalar_one()
    total = sum(r.n for r in rows)
    errs = sum(r.err or 0 for r in rows)
    ms = [r.ms for r in rows if r.ms]
    return {
        "used_today": total,
        "by_operation": {r.operation: r.n for r in rows},
        "error_rate": round(errs / total, 3) if total else 0,
        "avg_latency_ms": round(sum(ms) / len(ms)) if ms else 0,
        "cache_hits": cached,
        "cache_rate": round(cached / (total + cached), 3) if (total + cached) else 0,
    }


async def purge_call_logs(days: int = 90) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    async with session() as s:
        await s.execute(delete(ApiCallLog).where(ApiCallLog.called_at < cutoff))
        await s.commit()


async def put_categories(rows: list[dict]) -> None:
    if not rows:
        return
    ins = pg_insert(CategoryCode)
    stmt = ins.on_conflict_do_update(
        index_elements=["code"],
        set_={"name": ins.excluded.name, "level": ins.excluded.level},
    )
    async with session() as s:
        await s.execute(stmt, [
            {"code": r["code"], "name": r["name"], "level": r.get("level", 1)}
            for r in rows
        ])
        await s.commit()


async def categories() -> list[dict]:
    async with session() as s:
        rows = (await s.execute(select(CategoryCode).order_by(CategoryCode.code))).scalars()
        return [row(r) for r in rows]


async def chat_stats() -> dict:
    d = local_day(ChatMessage.created_at).label("d")
    async with session() as s:
        rows = (await s.execute(
            select(d, func.count().label("n"))
            .where(ChatMessage.role == "user")
            .group_by(d).order_by(d.desc()).limit(14)
        )).all()
        daily = [{"date": iso(r.d), "count": r.n} for r in rows]

        sessions_n = (await s.execute(
            select(func.count(func.distinct(ChatMessage.session_id)))
        )).scalar_one()

        tops = (await s.execute(
            select(RecentAttraction.title, func.count().label("n"))
            .group_by(RecentAttraction.title)
            .order_by(func.count().desc()).limit(10)
        )).all()
        top = [{"title": r.title, "count": r.n} for r in tops]

        users_n = (await s.execute(select(func.count()).select_from(User))).scalar_one()

    return {"daily": daily, "sessions": sessions_n, "users": users_n,
            "top_attractions": top}


async def history(session_id: str, limit: int = 20, before: int | None = None) -> list[dict]:
    where = [ChatMessage.session_id == session_id]
    if before is not None:
        where.append(ChatMessage.id < before)
    async with session() as s:
        rows = (await s.execute(
            select(ChatMessage).where(*where)
            .order_by(ChatMessage.id.desc()).limit(limit)
        )).scalars()
        out = [row(r) for r in rows]
    out.reverse()
    for r in out:
        r["tool_trace"] = json.loads(r["tool_trace"] or "[]")
    return out


async def history_has_more(session_id: str, oldest_id: int) -> bool:
    async with session() as s:
        return (await s.execute(
            select(func.count()).select_from(ChatMessage)
            .where(ChatMessage.session_id == session_id, ChatMessage.id < oldest_id)
        )).scalar_one() > 0
