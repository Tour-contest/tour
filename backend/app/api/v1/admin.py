from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, Path, Query
from pydantic import BaseModel, Field

from app.core import response
from app.core.response import EnvelopeRoute
from app.agent import llm
from app.core.config import settings
from app.core.deps import admin_user
from app.repository import db
from app.schemas.admin import (
    ApiCallsOut,
    BuildVectorsOut,
    ChatStatsOut,
    LlmMetricsOut,
    LoadAreaCodesOut,
    MappingStatsOut,
    UsersOut,
    VectorStatsOut,
)
from app.schemas.common import Envelope, OkOut, errors, example
from app.services import area, client, embedding, usecase

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(admin_user)],
                   route_class=EnvelopeRoute)


@router.get(
    "/metrics/api-calls",
    summary="공공데이터 호출 이력 조회",
    responses={200: {"model": Envelope[ApiCallsOut], "description": "성공", **example(
        {"date": "2026-09-06",
         "quota": {"limit": 100000, "used_today": 1469, "remaining": 98531},
         "by_operation": {"KorService2/detailCommon2": 812,
                          "TatsCnctrRateService/tatsCnctrRatedList": 402},
         "error_rate": 0.004, "avg_latency_ms": 318,
         "cache_hits": 260, "cache_rate": 0.15, "cache_enabled": True,
         "daily": [{"date": "2026-09-05", "real": 2210, "cached": 310}],
         "llm": {"calls": 96, "prompt": 184220, "completion": 20114, "since": "서버 시작 후"},
         "recent": [{"id": 48211, "session_id": None, "provider": "data.go.kr",
                     "operation": "KorService2/detailCommon2",
                     "params": "contentId=126165&serviceKey=***", "status_code": 200,
                     "result_code": "0000", "latency_ms": 262, "cache_hit": 0,
                     "called_at": "2026-09-06T09:11:02+09:00"}]})},
        **errors("401", "403", "422", "429")},
)
async def api_calls(
    limit: int = Query(default=100, ge=1, le=500, description="최근 호출 조회 건수"),
    provider: str | None = Query(None, description="제공자 필터. tourapi, naver"),
    day: str | None = Query(None, description="조회 일자(YYYY-MM-DD). 기본값은 오늘(KST)"),
):
    """공공데이터 호출 이력과 일일 한도 사용량. 심사용 API 활용 내역 화면을 겸한다.

    호출 시 메모리 버퍼를 먼저 기록하므로 다른 지표보다 응답이 느리다.

    cache_enabled 는 요청 내 중복 호출 제거 캐시의 활성 여부다. 원천 데이터 저장이
    아니며 시연 시 비활성화가 필요해 노출한다.

    llm 토큰은 메모리 카운터라 서버 재시작 시 0 으로 초기화된다.
    """
    await client.flush()
    target = day or db.today()
    summary = await db.call_summary(target)
    return {
        "date": target,
        "quota": {
            "limit": settings.daily_upstream_quota,
            "used_today": summary["used_today"],
            "remaining": max(0, settings.daily_upstream_quota - summary["used_today"]),
        },
        "by_operation": summary["by_operation"],
        "error_rate": summary["error_rate"],
        "avg_latency_ms": summary["avg_latency_ms"],
        "cache_hits": summary["cache_hits"],
        "cache_rate": summary["cache_rate"],
        "cache_enabled": settings.upstream_cache_enabled,
        "daily": await db.call_daily(7),
        "llm": {**llm.usage, "since": "서버 시작 후"},
        "recent": await db.call_logs(limit, provider),
    }


@router.get(
    "/metrics/llm",
    summary="모델 사용량·비용 조회",
    responses={200: {"model": Envelope[LlmMetricsOut], "description": "성공", **example(
        {"date": "2026-09-06", "model": "gpt-4o-mini",
         "price_per_1m": {"in": 0.075, "out": 0.3},
         "calls": 96, "prompt_tokens": 184220, "completion_tokens": 20114,
         "avg_latency_ms": 2140, "rate_limited": 2, "errors": 0,
         "by_purpose": [{"purpose": "tool", "calls": 60, "tokens": 150200},
                        {"purpose": "compose", "calls": 36, "tokens": 54134}],
         "cost_today_usd": 0.0198,
         "daily": [{"date": "2026-09-05", "prompt": 220110, "completion": 26400,
                    "calls": 112, "cost_usd": 0.0244}]})},
        **errors("401", "403", "429")},
)
async def llm_metrics():
    """모델 토큰 사용량과 단가 환산 비용. 토큰은 DB 실측값이고 비용은 설정된 단가로
    계산하므로 단가를 변경하면 과거 비용도 함께 바뀐다.
    """
    today = db.today()
    summary = await db.llm_summary(today)
    daily = await db.llm_daily(7)

    def cost(pt: int, ct: int) -> float:
        return round(pt / 1e6 * settings.llm_price_in_1m
                     + ct / 1e6 * settings.llm_price_out_1m, 4)

    return {
        "date": today,
        "model": settings.llm_model,
        "price_per_1m": {"in": settings.llm_price_in_1m, "out": settings.llm_price_out_1m},
        **summary,
        "cost_today_usd": cost(summary["prompt_tokens"], summary["completion_tokens"]),
        "daily": [{**d, "cost_usd": cost(d["prompt"], d["completion"])} for d in daily],
    }


@router.get(
    "/metrics/chat",
    summary="대화 통계 조회",
    responses={200: {"model": Envelope[ChatStatsOut], "description": "성공", **example(
        {"daily": [{"date": "2026-09-06", "count": 24}], "sessions": 41, "users": 10,
         "top_attractions": [{"title": "꽃지해수욕장", "count": 12}]})},
        **errors("401", "403", "429")},
)
async def chat_metrics():
    """일자별 질문 수, 세션·회원 수, 조회 상위 관광지."""
    return await db.chat_stats()


@router.get(
    "/metrics/mapping",
    summary="이름 매핑 현황 조회",
    responses={200: {"model": Envelope[MappingStatsOut], "description": "성공",
                     **example({"total": 8718, "matched": 7316, "areas": 256})},
               **errors("401", "403", "429")},
)
async def mapping_metrics():
    """혼잡도 관광지명과 관광정보 content_id 의 매핑 결과.

    matched 가 낮으면 상세로 이동할 수 있는 관광지가 그만큼 줄어든다.
    """
    return await db.mapping_stats()


@router.get(
    "/metrics/vectors",
    summary="벡터 현황 조회",
    responses={200: {"model": Envelope[VectorStatsOut], "description": "성공",
                     **example({"vectors": 3632, "areas": 254, "available": True})},
               **errors("401", "403", "429")},
)
async def vector_metrics():
    """유사도 벡터 적재 현황.

    available 이 false 면 임베딩 제공자가 연결되지 않은 상태이며 유사 관광지가 빈
    목록으로 응답한다. 소개문이 짧은 관광지는 벡터를 생성하지 않으므로 매핑 수보다
    벡터 수가 적다.
    """
    return {**await db.vector_stats(), "available": await embedding.available()}


@router.get(
    "/users",
    summary="회원 목록 조회",
    responses={200: {"model": Envelope[UsersOut], "description": "성공", **example(
        {"items": [{"id": "u_0f3a91", "provider": "kakao", "provider_uid": "3812004421",
                    "login_id": None, "nickname": "널널러", "role": "user", "status": "active",
                    "fail_count": 0, "locked_until": None,
                    "created_at": "2026-08-21T14:02:11+09:00",
                    "last_login_at": "2026-09-06T08:39:50+09:00"}],
         "page": {"limit": 50, "offset": 0, "total": 10, "has_more": False}})},
        **errors("401", "403", "422", "429")},
)
async def users(
    q: str = Query("", description="닉네임·로그인 아이디 부분일치"),
    limit: int = Query(default=50, ge=1, le=200, description="한 번에 받을 개수"),
    offset: int = Query(default=0, ge=0, description="건너뛸 개수"),
):
    """회원 목록. q 는 닉네임과 로그인 아이디 부분일치다.

    검색어를 변경하면 offset 을 0 으로 되돌린다.
    """
    items, total = await db.list_users(q, limit, offset)
    return response.page(items, limit=limit, offset=offset, total=total)


class StatusIn(BaseModel):
    status: Literal["active", "suspended"] = Field(
        description="active 또는 suspended", examples=["suspended"]
    )


@router.patch(
    "/users/{user_id}",
    summary="회원 상태 변경",
    responses={200: {"model": Envelope[OkOut], "description": "성공", **example({"ok": True})},
               **errors("401", "403", "422", "429")},
)
async def update_user(
    body: StatusIn,
    user_id: str = Path(description="회원 식별자", examples=["u_0f3a91"]),
):
    """회원 상태를 변경한다.

    suspended 로 변경하면 다음 요청부터 403 이다. 이미 발급된 액세스 토큰은 만료
    시점까지 유효하므로 즉시 차단되지는 않는다.
    """
    await db.set_user_status(user_id, body.status)
    return {"ok": True}


@router.post(
    "/load-area-codes",
    summary="지역코드 적재",
    responses={200: {"model": Envelope[LoadAreaCodesOut], "description": "성공", **example(
        {"categories": 4, "tour": 258, "crowd": 268, "saved": 268,
         "code_differs": 12, "tour_unmatched": ["세종특별자치시"]})},
        **errors("401", "403", "429", "502", "503")},
)
async def load_area_codes():
    """법정동 코드와 관광 지역코드를 받아 시군구 표를 채운다. 최초 1회만 호출한다.

    code_differs 는 두 체계의 코드가 다른 시군구 수, tour_unmatched 는 관광 쪽에서
    짝을 찾지 못한 이름이다.
    """
    return await area.load_codes()


@router.post(
    "/build-vectors/{signgu_cd}",
    summary="지역 벡터 생성",
    responses={200: {"model": Envelope[BuildVectorsOut], "description": "성공", **example(
        {"status": "ok", "built": 54, "total": 60, "signgu_nm": "태안군"})},
        **errors("401", "403", "404", "422", "429", "502", "503",
                 messages={"404": "모르는 지역 코드입니다"})},
)
async def build_vectors(
    signgu_cd: str = Path(description="시군구 코드", examples=["44825"]),
    limit: int = Query(default=60, ge=1, le=200, description="한 번에 생성할 최대 개수"),
):
    """해당 지역의 유사도 벡터를 생성한다.

    관광지 1건당 상세 조회 1회와 임베딩 1회를 사용한다. limit 상한이 200 인 이유는
    한 번의 호출로 일일 한도를 소진하지 않게 하기 위해서다.

    소개문이 40자 미만이면 유사도가 의미 없어 건너뛴다. 임베딩 차원이 바뀌면 기동
    시점에 벡터 테이블을 재생성하므로 제공자를 변경하면 전부 다시 만들어야 한다.
    """
    return await usecase.build_vectors(signgu_cd, limit)
