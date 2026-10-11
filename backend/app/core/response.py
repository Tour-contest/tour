from __future__ import annotations

import json
from datetime import datetime
from typing import Any, Callable
from zoneinfo import ZoneInfo

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute

from app.core.config import settings

try:
    _TZ = ZoneInfo(settings.report_tz)
except Exception:
    _TZ = datetime.now().astimezone().tzinfo

RAW_PATHS = ("/chat/stream", "/auth/kakao/webhook")


def now() -> str:
    return datetime.now(_TZ).isoformat(timespec="seconds")


def ok(data: Any = None, code: str = "OK") -> dict:
    return {
        "success": True,
        "code": code,
        "message": None,
        "data": data,
        "retriable": False,
        "timestamp": now(),
    }


def fail(code: str, message: str, *, retriable: bool = False) -> dict:
    return {
        "success": False,
        "code": code,
        "message": message,
        "data": None,
        "retriable": retriable,
        "timestamp": now(),
    }


def error_response(status: int, code: str, message: str, *, retriable: bool = False) -> JSONResponse:
    return JSONResponse(status_code=status, content=fail(code, message, retriable=retriable))


def page(items: list, *, limit: int, offset: int, total: int) -> dict:
    return {
        "items": items,
        "page": {
            "limit": limit,
            "offset": offset,
            "total": total,
            "has_more": offset + len(items) < total,
        },
    }


class EnvelopeRoute(APIRoute):
    def get_route_handler(self) -> Callable:
        original = super().get_route_handler()

        async def wrapped(request: Request) -> Response:
            response = await original(request)
            if request.url.path.endswith(RAW_PATHS):
                return response
            if not isinstance(response, JSONResponse):
                return response

            body = json.loads(response.body) if response.body else None
            if isinstance(body, dict) and "success" in body:
                return response

            keep = {k: v for k, v in response.headers.items()
                    if k.lower() not in ("content-length", "content-type")}
            return JSONResponse(status_code=response.status_code, content=ok(body), headers=keep)

        return wrapped
