from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from logging.handlers import TimedRotatingFileHandler
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1 import admin, areas, attractions, auth, chat, system
from app.core import openapi, ratelimit, response
from app.core.config import settings
from app.core.errors import AppError
from app.repository import db
from app.schemas.system import RootOut
from app.services import area as area_svc
from app.services import auth as auth_svc
from app.services import client

log = logging.getLogger("tour")
Path("logs").mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    handlers=[
        logging.StreamHandler(),
        TimedRotatingFileHandler(
            "logs/app.log", when="midnight", backupCount=14, encoding="utf-8"
        ),
    ],
)
# httpx 는 INFO 에서 요청 URL 전체를 찍어 serviceKey 가 로그에 남는다. 경고 이상만 남긴다.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)


def check_secrets() -> None:
    if len(settings.jwt_secret) < 32:
        raise RuntimeError("JWT_SECRET 없음 또는 32자 미만")
    if not settings.allow_dev_login:
        if "test-only" in settings.jwt_secret or "change" in settings.jwt_secret:
            raise RuntimeError("운영 구성에서 JWT_SECRET 테스트용 값 사용 불가")
        if settings.admin_login_id and settings.admin_password in ("", "admin1234!"):
            raise RuntimeError("운영 구성에서 관리자 비밀번호 없음 또는 기본값 사용 불가")
        if "*" in settings.cors_list:
            raise RuntimeError("운영 구성에서 CORS_ORIGINS * 사용 불가")


@asynccontextmanager
async def lifespan(app: FastAPI):
    check_secrets()
    await db.init()
    await auth_svc.ensure_admin()
    await client.load_today_count()
    await db.purge_call_logs(90)
    await db.purge_refresh_tokens()
    try:
        await area_svc.ensure_loaded()
        log.info("area_codes: %d", await db.area_count())
    except Exception as e:
        log.warning("지역코드 적재 실패, /api/v1/admin/load-area-codes 재시도 필요: %s", e)

    flusher = asyncio.create_task(client.flush_loop())
    yield
    flusher.cancel()
    try:
        await flusher
    except asyncio.CancelledError:
        pass
    await client.close_client()
    await db.close()


app = FastAPI(
    title=openapi.TITLE,
    version=openapi.VERSION,
    description=openapi.DESCRIPTION,
    openapi_tags=openapi.TAGS,
    lifespan=lifespan,
)


@app.middleware("http")
async def guard_errors(request: Request, call_next):
    """레이트리밋과 미처리 예외를 CORS 안쪽에서 처리한다.

    Starlette 는 나중에 붙인 미들웨어가 바깥에 온다. 이 미들웨어가 CORS 보다 먼저 붙어
    안쪽에 있으므로 여기서 만든 429·500 응답에도 CORS 헤더가 붙는다. 바깥의
    ServerErrorMiddleware 까지 예외가 올라가면 브라우저는 본문을 읽지 못한다.
    """
    try:
        return await ratelimit.middleware(request, call_next)
    except Exception:
        log.exception("미처리 오류: %s", request.url.path)
        return response.error_response(
            500, "INTERNAL_ERROR",
            "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.", retriable=True,
        )


# Bearer 토큰만 쓰므로 쿠키용 allow_credentials 는 켜지 않는다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    return response.error_response(
        exc.http_status, exc.code, exc.message, retriable=exc.retriable
    )


@app.exception_handler(HTTPException)
async def http_error_handler(request: Request, exc: HTTPException):
    d = exc.detail
    if isinstance(d, dict) and "code" in d:
        code, message = d["code"], d.get("message", "")
        retriable = d.get("retriable", False)
    else:
        code = {401: "UNAUTHORIZED", 403: "FORBIDDEN", 404: "NOT_FOUND",
                429: "RATE_LIMITED"}.get(exc.status_code, "ERROR")
        message = d if isinstance(d, str) else "요청을 처리하지 못했습니다"
        retriable = exc.status_code >= 500
    return response.error_response(exc.status_code, code, message, retriable=retriable)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    first = exc.errors()[0] if exc.errors() else {}
    field = ".".join(str(x) for x in first.get("loc", [])[1:]) or "입력"
    return response.error_response(422, "INVALID_INPUT", f"{field} 값을 확인해주세요")


@app.exception_handler(Exception)
async def unhandled_handler(request: Request, exc: Exception):
    log.exception("미처리 오류: %s", request.url.path)
    return response.error_response(
        500, "INTERNAL_ERROR",
        "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.", retriable=True,
    )


for r in (
    system.router,
    auth.router,
    admin.router,
    areas.router,
    attractions.router,
    chat.router,
):
    app.include_router(r, prefix="/api/v1")


@app.get(
    "/",
    tags=["system"],
    summary="API 안내",
    response_model=RootOut,
)
async def root():
    """API 문서 위치."""
    return {"name": "널널 API", "docs": "/docs", "openapi": "/openapi.json"}
