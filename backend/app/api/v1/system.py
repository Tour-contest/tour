from __future__ import annotations

from fastapi import APIRouter

from app.core.response import EnvelopeRoute
from app.core.config import settings
from app.repository import db
from app.schemas.common import Envelope, errors, example
from app.schemas.system import AttributionOut, HealthOut, ReadyOut
from app.services import embedding

router = APIRouter(tags=["system"], route_class=EnvelopeRoute)


@router.get(
    "/healthz",
    summary="헬스 체크",
    responses={200: {"model": Envelope[HealthOut], "description": "성공",
                     **example({"ok": True})}},
)
async def healthz():
    """프로세스 생존 확인. 레이트리밋 대상에서 제외된다."""
    return {"ok": True}


@router.get(
    "/readyz",
    summary="서비스 준비 상태 조회",
    responses={200: {"model": Envelope[ReadyOut], "description": "성공", **example(
        {"ok": True, "areas_loaded": 268, "llm_enabled": True, "llm_model": "gpt-4o-mini",
         "embedding_ready": True, "service_key_set": True})}},
)
async def readyz():
    """지역코드 적재 건수와 대화·임베딩 동작 상태.

    llm_enabled 가 false 면 대화는 규칙 기반으로 동작한다. 응답 형식은 동일하다.
    """
    areas = await db.area_count()
    return {
        "ok": areas > 0,
        "areas_loaded": areas,
        "llm_enabled": settings.llm_enabled,
        "llm_model": settings.llm_model if settings.llm_enabled else None,
        "embedding_ready": await embedding.available(),
        "service_key_set": bool(settings.data_go_kr_service_key),
    }


@router.get(
    "/meta/attribution",
    summary="출처 표기 문구 조회",
    responses={200: {"model": Envelope[AttributionOut], "description": "성공", **example(
        {"text": "출처: ⓒ한국관광공사",
         "note": "로고(CI/BI) 이미지는 사용 금지. 'TourAPI' 단독 표기도 지양."})},
        **errors("429")},
)
async def attribution():
    """관광 데이터를 노출하는 화면에 표기할 문구."""
    return {
        "text": "출처: ⓒ한국관광공사",
        "note": "로고(CI/BI) 이미지는 사용 금지. 'TourAPI' 단독 표기도 지양.",
    }
