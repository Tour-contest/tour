from __future__ import annotations

import time
from collections import defaultdict, deque

from fastapi import Request

from app.core import response
from app.core.config import settings

_hits: dict[str, deque] = defaultdict(deque)


def allow(key: str, limit: int, window: int = 60) -> tuple[bool, int]:
    now = time.monotonic()
    q = _hits[key]
    while q and q[0] <= now - window:
        q.popleft()
    if len(q) >= limit:
        return False, int(window - (now - q[0])) + 1
    if not q:
        del _hits[key]
    _hits[key].append(now)
    return True, 0


def who(request: Request) -> tuple[str, bool]:
    h = request.headers.get("authorization") or ""
    if h.lower().startswith("bearer "):
        from app.core import security

        payload = security.decode(h[7:].strip())
        if payload and payload.get("typ") == "access" and payload.get("sub"):
            return f"u:{payload['sub']}", True
    ip = ""
    if settings.trust_forwarded_for:
        ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    return f"ip:{ip or (request.client.host if request.client else 'unknown')}", False


_NO_LIMIT = ("/healthz", "/readyz", "/auth/kakao/webhook")


async def middleware(request: Request, call_next):
    path = request.url.path
    if not path.startswith("/api/v1") or path.endswith(_NO_LIMIT):
        return await call_next(request)

    ident, logged_in = who(request)

    if path.endswith("/chat/stream"):
        ok, wait = allow(f"{ident}:chat", settings.rate_chat_per_min)
        label = "대화 요청이 너무 잦습니다"
    else:
        limit = settings.rate_user_per_min if logged_in else settings.rate_anon_per_min
        ok, wait = allow(ident, limit)
        label = "요청이 너무 잦습니다"

    if not ok:
        res = response.error_response(
            429, "RATE_LIMITED", f"{label}. {wait}초 뒤에 다시 시도해주세요.", retriable=True
        )
        res.headers["Retry-After"] = str(wait)
        return res
    return await call_next(request)
