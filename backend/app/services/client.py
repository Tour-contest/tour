from __future__ import annotations

import asyncio
import contextvars
import time
from datetime import datetime, timezone
from typing import Any

import httpx

from app.core import clock
from app.core.config import settings
from app.core.errors import (
    BudgetExceeded,
    QuotaExceeded,
    UpstreamError,
    UpstreamMalformed,
    UpstreamTimeout,
)

BASE = "https://apis.data.go.kr/B551011"
KMA_BASE = "https://apis.data.go.kr/1360000"

# 관광공사 외 기관의 서비스는 여기에 기관 경로를 적는다. 없으면 관광공사다.
BASE_OF = {
    "VilageFcstInfoService_2.0": KMA_BASE,
    "MidFcstInfoService": KMA_BASE,
}

_client: httpx.AsyncClient | None = None
_global_sem = asyncio.Semaphore(8)
_cache: dict[str, tuple[float, Any]] = {}
_inflight: dict[str, asyncio.Task] = {}

MIN_INTERVAL = 0.15
_pace_lock = asyncio.Lock()
_last_call = 0.0

_blocked: dict[str, str] = {}

_OP_NM = {
    "KorService2/searchKeyword2": "관광지 검색",
    "KorService2/detailCommon2": "관광지 상세",
    "KorService2/detailIntro2": "관광지 이용 안내",
    "KorService2/areaBasedList2": "지역별 관광지 목록",
    "KorService2/detailInfo2": "관광지 상세 항목",
    "KorService2/ldongCode2": "법정동 코드",
    "TatsCnctrRateService/tatsCnctrRatedList": "관광지 집중률",
    "VilageFcstInfoService_2.0/getVilageFcst": "단기예보",
    "VilageFcstInfoService_2.0/getUltraSrtNcst": "초단기실황",
    "MidFcstInfoService/getMidLandFcst": "중기육상예보",
    "MidFcstInfoService/getMidTa": "중기기온",
}

OK_CODES = {"0000", "00"}
NO_DATA_CODES = {"03"}


def is_daily_limit(text: str) -> bool:
    return "LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS" in text


def block(operation: str) -> None:
    _blocked[operation] = clock.today_str()


def blocked_ops() -> list[str]:
    today = clock.today_str()
    return [s for s, d in _blocked.items() if d == today]


_budget: contextvars.ContextVar[list | None] = contextvars.ContextVar("upstream_budget", default=None)


def begin_budget(limit: int | None = None) -> None:
    _budget.set([0, limit or settings.max_upstream_calls_per_request])


def budget_used() -> int:
    b = _budget.get()
    return b[0] if b else 0


def budget_exhausted() -> bool:
    b = _budget.get()
    return bool(b) and b[0] >= b[1]


def spend_budget(operation: str) -> None:
    b = _budget.get()
    if b is None:
        return
    if b[0] >= b[1]:
        raise BudgetExceeded(
            "이번 요청에서 쓸 수 있는 조회 횟수를 다 썼어요.",
            detail=f"{operation} request budget {b[1]}",
        )
    b[0] += 1


def blocked_error(operation: str) -> QuotaExceeded:
    nm = _OP_NM.get(operation, operation)
    return QuotaExceeded(
        f"{nm} 조회 한도를 오늘 다 썼어요. 내일 다시 시도해주세요.",
        detail=f"{operation} daily limit",
    )


async def pace() -> None:
    global _last_call
    async with _pace_lock:
        wait = _last_call + MIN_INTERVAL - time.monotonic()
        if wait > 0:
            await asyncio.sleep(wait)
        _last_call = time.monotonic()

call_log: list[dict] = []
_pending: list[dict] = []
_today_count: dict[str, int] = {}
_today_key = ""
_quota_lock = asyncio.Lock()


def service(operation: str) -> str:
    return operation.split("/", 1)[0]


def get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=httpx.Timeout(connect=2.0, read=8.0, write=5.0, pool=5.0),
            limits=httpx.Limits(max_connections=32, max_keepalive_connections=16),
        )
    return _client


async def close_client() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


def mask(params: dict) -> dict:
    out = dict(params)
    for k in ("serviceKey", "X-NCP-APIGW-API-KEY"):
        if k in out:
            out[k] = "***"
    return out


def cache_key(op: str, params: dict) -> str:
    items = sorted((k, str(v)) for k, v in params.items() if k != "serviceKey")
    return op + "|" + "&".join(f"{k}={v}" for k, v in items)


def parse(payload: dict) -> tuple[list[dict], int]:
    if "OpenAPI_ServiceResponse" in payload:
        hdr = payload["OpenAPI_ServiceResponse"].get("cmmMsgHeader", {})
        raise UpstreamError(hdr.get("errMsg", "unknown"))

    if "response" not in payload:
        raise UpstreamError(payload.get("resultMsg", "unknown"))

    header = payload["response"].get("header", {})
    code = header.get("resultCode")
    if code in NO_DATA_CODES:
        return [], 0
    if code not in OK_CODES:
        raise UpstreamError(header.get("resultMsg", "unknown"))

    body = payload["response"].get("body") or {}
    total = int(body.get("totalCount") or 0)
    items = body.get("items")
    if not items:
        return [], total

    item = items.get("item") if isinstance(items, dict) else None
    if item is None:
        return [], total
    return (item if isinstance(item, list) else [item]), total


async def call(
    operation: str,
    params: dict,
    *,
    ttl: int | None = None,
    session_id: str | None = None,
    common: bool = True,
) -> tuple[list[dict], int]:
    """공공데이터포털 API 한 번 호출. 기관은 operation 의 서비스명으로 정해진다(BASE_OF).

    common 은 관광공사 공통 파라미터(MobileOS·MobileApp·_type)를 붙일지 여부다.
    """
    q = {"serviceKey": settings.data_go_kr_service_key}
    if common:
        q.update({"MobileOS": "ETC", "MobileApp": settings.tourapi_mobile_app, "_type": "json"})
    q.update(params)

    ck = cache_key(operation, q)
    if settings.upstream_cache_enabled and ttl:
        hit = _cache.get(ck)
        if hit:
            if hit[0] > time.monotonic():
                record(operation, q, 200, "cache", 0, True, session_id)
                return hit[1]
            del _cache[ck]

    task = _inflight.get(ck)
    if task is None:
        spend_budget(operation)
        task = asyncio.ensure_future(fetch(operation, q, ck, ttl, session_id))
        _inflight[ck] = task
        task.add_done_callback(lambda _t, ck=ck: _inflight.pop(ck, None))
    else:
        record(operation, q, 200, "inflight", 0, True, session_id)
    return await task


async def fetch(
    operation: str, q: dict, ck: str, ttl: int | None, session_id: str | None
) -> tuple[list[dict], int]:
    if operation in blocked_ops():
        record(operation, q, 429, "daily_limit_cached", 0, False, session_id)
        raise blocked_error(operation)

    svc = service(operation)
    base = BASE_OF.get(svc, BASE)
    async with _quota_lock:
        if _today_key != clock.today_str():
            await load_today_count()
        if _today_count.get(svc, 0) >= settings.daily_upstream_quota:
            raise QuotaExceeded(
                f"{_OP_NM.get(operation, svc)} 조회 한도를 오늘 다 썼어요. 내일 다시 시도해주세요.",
                detail=f"{svc} {_today_count.get(svc, 0)}/{settings.daily_upstream_quota}",
            )
        _today_count[svc] = _today_count.get(svc, 0) + 1

    last_exc: Exception | None = None
    backoff = [0.6, 1.5, 3.0]

    for attempt in range(4):
        try:
            started = time.monotonic()
            await pace()
            async with _global_sem:
                r = await get_client().get(f"{base}/{operation}", params=q)
            elapsed = int((time.monotonic() - started) * 1000)

            if is_daily_limit(r.text):
                block(operation)
                record(operation, q, 429, "daily_limit", elapsed, False, session_id)
                raise blocked_error(operation)

            if r.status_code == 429 or r.status_code >= 500:
                if attempt < 3:
                    await asyncio.sleep(backoff[attempt])
                    continue
                record(operation, q, r.status_code, "rate_limited", elapsed, False, session_id)
                raise UpstreamError(f"{operation}: 호출 과다로 거부 ({r.status_code})")

            text = r.text.lstrip()
            if not text.startswith("{"):
                record(operation, q, r.status_code, "non-json", elapsed, False, session_id)
                raise UpstreamMalformed(f"{operation}: JSON 이 아닌 응답")

            try:
                payload = r.json()
            except ValueError as e:
                record(operation, q, r.status_code, "non-json", elapsed, False, session_id)
                raise UpstreamMalformed(f"{operation}: JSON 파싱 실패") from e
            try:
                result = parse(payload)
            except UpstreamError as e:
                record(operation, q, r.status_code, getattr(e, "message", "error"),
                        elapsed, False, session_id)
                raise
            record(operation, q, r.status_code, "0000", elapsed, False, session_id)
            if settings.upstream_cache_enabled and ttl:
                _cache[ck] = (time.monotonic() + ttl, result)
                evict_expired_cache()
            return result

        except httpx.HTTPError as e:
            last_exc = e
            if attempt < 3:
                await asyncio.sleep(backoff[attempt])
                continue
            record(operation, q, 0, "timeout", 0, False, session_id)
            raise UpstreamTimeout(f"{operation}: 응답 지연") from e

    raise UpstreamError(str(last_exc))


async def call_all(
    operation: str,
    params: dict,
    *,
    page_size: int | None = None,
    max_pages: int = 20,
    ttl: int | None = None,
    session_id: str | None = None,
) -> list[dict]:
    size = page_size or settings.crowd_page_size
    first, total = await call(
        operation, {**params, "numOfRows": size, "pageNo": 1}, ttl=ttl, session_id=session_id
    )
    rows = list(first)
    if not rows or len(rows) >= total:
        return rows

    pages = min(max_pages, -(-total // max(len(rows), 1)))
    if pages <= 1:
        return rows

    tasks = [
        call(operation, {**params, "numOfRows": size, "pageNo": p}, ttl=ttl, session_id=session_id)
        for p in range(2, pages + 1)
    ]
    for res in await asyncio.gather(*tasks, return_exceptions=True):
        if isinstance(res, Exception):
            continue
        rows.extend(res[0])
        if len(rows) >= total:
            break
    return rows


def record_row(row: dict) -> None:
    call_log.append(row)
    if len(call_log) > 500:
        del call_log[: len(call_log) - 500]
    _pending.append(row)


def record(op, params, status, result_code, latency, cache_hit, session_id) -> None:
    record_row({
        "called_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "provider": "data.go.kr",
        "operation": op,
        "params": mask(params),
        "status_code": status,
        "result_code": result_code,
        "latency_ms": latency,
        "cache_hit": cache_hit,
        "session_id": session_id,
    })


def evict_expired_cache() -> None:
    if len(_cache) <= 512:
        return
    now = time.monotonic()
    for k in [k for k, (exp, _) in _cache.items() if exp <= now]:
        del _cache[k]


def quota_used() -> int:
    return sum(_today_count.values())


def quota_left() -> int:
    return max(0, settings.daily_upstream_quota - quota_used())


async def load_today_count() -> None:
    """오늘(KST) 호출 수를 DB 에서 다시 센다.

    기동 시, 날짜가 바뀔 때, 그리고 flush_loop 가 주기적으로 부른다. 배치 프로세스가 쓴
    호출도 DB 를 거쳐 여기로 합산되므로 서버와 배치가 같은 한도를 본다.
    """
    global _today_key
    from app.repository import db

    today = clock.today_str()
    summary = await db.call_summary(today, provider="data.go.kr")
    counts: dict[str, int] = {}
    for op, n in summary["by_operation"].items():
        svc = service(op)
        counts[svc] = counts.get(svc, 0) + n
    _today_count.clear()
    _today_count.update(counts)
    _today_key = today


async def flush() -> int:
    global _pending
    if not _pending:
        return 0
    from app.repository import db

    rows, _pending = _pending, []
    try:
        await db.add_call_logs(rows)
    except Exception:
        _pending = rows + _pending
        del _pending[:-5000]
        raise
    return len(rows)


RESYNC_EVERY = 12


async def flush_loop(interval: int = 5) -> None:
    """호출 로그를 주기적으로 DB 에 내리고, 한 번씩 오늘 카운터를 DB 기준으로 다시 맞춘다."""
    import logging

    log = logging.getLogger("tour.client")
    tick = 0
    while True:
        try:
            await asyncio.sleep(interval)
            await flush()
            tick += 1
            if tick % RESYNC_EVERY == 0:
                await load_today_count()
        except asyncio.CancelledError:
            try:
                await flush()
            except Exception:
                log.warning("종료 중 호출 로그 저장 실패")
            raise
        except Exception as e:
            log.warning("호출 로그 저장 실패: %s", type(e).__name__)
