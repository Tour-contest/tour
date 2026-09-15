from __future__ import annotations

from datetime import date as _date

from fastapi import APIRouter, Depends, HTTPException, Path, Query

from app.core.response import EnvelopeRoute
from app.core.config import settings
from app.core.deps import current_user
from app.core.errors import QuotaExceeded
from app.repository import db
from app.schemas.attraction import (
    AlternativesOut,
    CrowdOut,
    DetailOut,
    ImagesOut,
    InterestOut,
    PetOut,
    RecentOut,
    SearchOut,
    SimilarOut,
)
from app.schemas.common import Envelope, OkOut, errors, example
from app.services import usecase

router = APIRouter(tags=["attractions"], dependencies=[Depends(current_user)],
                   route_class=EnvelopeRoute)

CID = Path(description="관광정보 콘텐츠 ID. 검색 응답의 content_id", examples=["126165"])
SOURCE = "출처: ⓒ한국관광공사"


def ymd(value: _date | None) -> str | None:
    return value.isoformat() if value else None


@router.get(
    "/attractions/search",
    summary="관광지 검색",
    responses={200: {"model": Envelope[SearchOut], "description": "성공", **example(
        {"status": "ok", "confident": True,
         "items": [{"content_id": "126165", "title": "꽃지해수욕장",
                    "addr1": "충남 태안군 안면읍 꽃지해안로", "content_type_id": "12",
                    "tour_cd": "34_14", "signgu_cd": "44825", "signgu_nm": "태안군",
                    "image": "http://tong.visitkorea.or.kr/...",
                    "mapx": "126.3312", "mapy": "36.5024"}],
         "source": SOURCE})},
        **errors("401", "422", "429", "502", "503")},
)
async def search(
    keyword: str = Query(min_length=1, description="관광지명", examples=["꽃지"]),
    signgu_cd: str | None = Query(None, description="시군구 코드. 주면 상류 호출을 줄인다",
                                  examples=["44825"]),
):
    """관광지명으로 검색한다.

    confident 가 true 면 단일 후보로 확정된 결과다. false 인 상태에서 items[0] 을
    선택하면 다른 관광지가 열린다.

    signgu_cd 를 함께 주면 이미 매핑된 관광지는 상류 호출 없이 응답한다. 갈래별
    목록(캠핑장, 음식점 등)은 이 엔드포인트가 아니라 대화 도구로 제공한다.
    """
    return await usecase.find_attraction(keyword, signgu_cd)


@router.get(
    "/attractions/{content_id}",
    summary="관광지 상세 조회",
    responses={200: {"model": Envelope[DetailOut], "description": "성공", **example(
        {"status": "ok", "content_id": "126165", "title": "꽃지해수욕장",
         "addr1": "충남 태안군 안면읍 꽃지해안로 293-4", "tel": "041-670-2691",
         "overview": "안면도 남단에 있는 해수욕장으로 할미바위와 할아비바위 사이로 지는 낙조가 유명하다.",
         "content_type_id": "12", "tour_cd": "34_14", "signgu_cd": "44825",
         "signgu_nm": "태안군", "sido_nm": "충청남도",
         "image": "http://tong.visitkorea.or.kr/...",
         "info": [{"name": "이용시간", "value": "상시"}, {"name": "주차시설", "value": "가능"}],
         "pet": [], "source": SOURCE})},
        **errors("401", "404", "429", "502", "503",
                 messages={"404": "관광지를 찾을 수 없습니다"})},
)
async def detail(content_id: str = CID, user: dict = Depends(current_user)):
    """관광지 상세. 상세 화면의 첫 조회다.

    성공하면 서버가 최근 본 관광지에 기록한다. 클라이언트가 등록하는 API 는 없다.

    404 나 503 이면 상세 화면의 나머지 조회는 호출하지 않는다. 없는 관광지이거나
    한도가 소진된 상태라 결과를 쓸 수 없다.
    """
    res = await usecase.attraction_detail(content_id)
    if res["status"] == "quota_exceeded":
        raise QuotaExceeded(res.get("message") or "조회 한도를 오늘 다 썼어요. 내일 다시 시도해주세요.")
    if res["status"] != "ok":
        raise HTTPException(404, "관광지를 찾을 수 없습니다")

    try:
        crowd = await usecase.crowd_for_content(content_id, days=1)
        level = crowd["series"][0]["level"] if crowd.get("series") else None
    except Exception:
        level = None
    await db.touch_recent(
        user["id"],
        {
            "content_id": content_id,
            "title": res["title"],
            "signgu_cd": res.get("signgu_cd"),
            "signgu_nm": res.get("signgu_nm"),
            "last_level": level,
        },
        settings.recent_attractions_limit,
    )
    return res


@router.get(
    "/attractions/{content_id}/crowd",
    summary="관광지 혼잡도 조회",
    responses={200: {"model": Envelope[CrowdOut], "description": "성공", **example(
        {"status": "ok", "content_id": "126165", "has_data": True,
         "matched_name": "꽃지해수욕장", "match_method": "exact", "match_confidence": 1.0,
         "series": [{"date": "2026-09-06", "weekday": "일", "rate": 41.2, "level": "한적"},
                    {"date": "2026-09-07", "weekday": "월", "rate": 58.9, "level": "보통"},
                    {"date": "2026-09-08", "weekday": "화", "rate": 82.4, "level": "혼잡"}],
         "summary": {"peak_date": "2026-09-08", "peak_rate": 82.4,
                     "min_date": "2026-09-06", "min_rate": 41.2, "avg": 60.8},
         "available_days": 28, "signgu_cd": "44825", "signgu_nm": "태안군",
         "source": SOURCE})},
        **errors("401", "404", "422", "429", "502", "503")},
)
async def crowd(
    content_id: str = CID,
    days: int = Query(default=7, ge=1, le=30, description="조회 기간(일)"),
    date_from: _date | None = Query(None, description="YYYY-MM-DD. 비우면 오늘부터. 형식이 틀리면 422"),
):
    """일자별 예측 혼잡도와 기간 요약.

    rate 는 집중률이며 백분율 기호를 붙이지 않는다. 등급은 혼잡, 보통, 한적 세 가지다.
    예측값이므로 첫 노출 시 고지가 필요하다.

    기간 토글은 이 엔드포인트만 다시 호출한다.
    """
    return await usecase.crowd_for_content(
        content_id, days=days, date_from=ymd(date_from)
    )


@router.get(
    "/attractions/{content_id}/alternatives",
    summary="대안 관광지 조회",
    responses={200: {"model": Envelope[AlternativesOut], "description": "성공", **example(
        {"status": "ok",
         "base": {"name": "꽃지해수욕장", "rate": 88.0, "level": "혼잡"},
         "items": [{"content_id": "126266", "name": "운여해변", "rate": 28.4, "level": "한적",
                    "date": "2026-09-06", "image": "", "addr1": "충남 태안군 안면읍",
                    "reason": {"lower_by": 59.6, "same_category": True,
                               "distance_km": 7.4, "similarity": 0.545}}],
         "sort_basis": "crowding", "relaxed": False, "candidate_source": "related",
         "signgu_nm": "태안군", "source": SOURCE})},
        **errors("401", "404", "422", "429", "502", "503")},
)
async def alternatives(
    content_id: str = CID,
    date: _date | None = Query(None, description="YYYY-MM-DD. 비우면 오늘 기준. 형식이 틀리면 422"),
    limit: int = Query(default=5, ge=1, le=10, description="최대 개수. 화면은 상위 3개만 그린다"),
):
    """기준 관광지와 같은 지역의 대안 관광지.

    혼잡도를 1순위로 정렬하고 같은 구간 안에서만 유사도를 반영한다. 클라이언트에서
    유사도로 재정렬하면 더 붐비는 곳이 상위로 올라온다.

    candidate_source 는 후보를 어디서 골랐는지 나타낸다. related 는 연관 관광지,
    area 는 지역 전체, related+area 는 둘을 합친 것이다.
    """
    return await usecase.recommend_alternatives(content_id, ymd(date), limit)


@router.get(
    "/attractions/{content_id}/interest",
    summary="검색 관심도 조회",
    responses={200: {"model": Envelope[InterestOut], "description": "성공", **example(
        {"status": "ok",
         "items": [{"name": "꽃지", "display_name": "꽃지해수욕장",
                    "trend": "falling", "change_pct": -23.5, "weeks": 8}]})},
        **errors("401", "404", "422", "429", "502", "503",
                 messages={"404": "관광지를 찾을 수 없습니다"})},
)
async def interest(
    content_id: str = CID,
    weeks: int | None = Query(None, ge=1, le=52, description="조회 기간(주)"),
):
    """네이버 데이터랩 기준 검색 관심도 추세. 최근 4주 기울기로 rising·falling·flat 을 판정한다.

    no_data 가 흔한 정상 상태이므로 오류가 아니라 영역 미표시로 처리한다.
    """
    d = await usecase.attraction_detail(content_id)
    if d["status"] == "quota_exceeded":
        raise QuotaExceeded(d.get("message") or "조회 한도를 오늘 다 썼어요. 내일 다시 시도해주세요.")
    if d["status"] != "ok":
        raise HTTPException(404, "관광지를 찾을 수 없습니다")
    return await usecase.interest_trend([d["title"]], weeks, d.get("signgu_nm", ""))


@router.get(
    "/attractions/{content_id}/images",
    summary="관광지 이미지 조회",
    responses={200: {"model": Envelope[ImagesOut], "description": "성공", **example(
        {"status": "ok",
         "items": [{"url": "http://tong.visitkorea.or.kr/...jpg",
                    "small": "http://tong.visitkorea.or.kr/...s.jpg",
                    "name": "꽃지해수욕장", "copyright": "공공누리 제1유형 (출처표시)"}],
         "source": SOURCE})},
        **errors("401", "429", "502", "503")},
)
async def images(content_id: str = CID):
    """상세 화면 캐러셀용 서브 이미지.

    copyright 는 공공누리 유형 표기 문구다. no_data 가 정상이다.
    """
    return await usecase.attraction_images(content_id)


@router.get(
    "/attractions/{content_id}/pet",
    summary="반려동물 동반 정보 조회",
    responses={200: {"model": Envelope[PetOut], "description": "성공", **example(
        {"status": "no_data", "items": [], "source": SOURCE})},
        **errors("401", "429", "502", "503")},
)
async def pet(content_id: str = CID):
    """반려동물 동반 정보. 등록된 관광지가 적어 no_data 가 일반적이다."""
    return await usecase.attraction_pet(content_id)


@router.get(
    "/attractions/{content_id}/similar",
    summary="유사 관광지 조회",
    responses={200: {"model": Envelope[SimilarOut], "description": "성공", **example(
        {"status": "ok",
         "items": [{"content_id": "126266", "title": "운여해변",
                    "lcls1": "NA", "lcls2": "NA01", "similarity": 0.545},
                   {"content_id": "126189", "title": "백리포해수욕장",
                    "lcls1": "NA", "lcls2": "NA01", "similarity": 0.54}],
         "source": SOURCE})},
        **errors("401", "404", "422", "429", "503")},
)
async def similar(
    content_id: str = CID,
    limit: int = Query(default=5, ge=1, le=50, description="최대 몇 곳"),
):
    """소개문 임베딩의 코사인 유사도 상위 목록.

    상류 호출 없이 DB(pgvector)에서 계산하는 유일한 조회다.

    유사도 절대값은 임베딩 모델에 따라 분포가 다르므로(ollama 0.6~0.9,
    upstage 0.37~0.55) 수치 자체보다 순위 용도로 사용한다. 벡터를 생성하지 않은
    지역은 no_data 다.
    """
    return await usecase.similar_attractions(content_id, limit)


@router.get(
    "/me/recent-attractions",
    summary="최근 본 관광지 조회",
    responses={200: {"model": Envelope[RecentOut], "description": "성공", **example(
        {"items": [{"content_id": "126165", "title": "꽃지해수욕장", "signgu_cd": "44825",
                    "signgu_nm": "태안군", "last_level": "혼잡",
                    "viewed_at": "2026-09-06T09:04:22+09:00"}]})},
        **errors("401", "429")},
)
async def recent(user: dict = Depends(current_user)):
    """최근 조회한 관광지.

    상세 조회와 대화에서 관광지가 확정될 때 서버가 기록한다. 등록 API 는 없다.
    last_level 은 기록 시점의 등급이며 현재 값이 아니다.
    """
    return {"items": await db.list_recent(user["id"])}


@router.delete(
    "/me/recent-attractions",
    summary="최근 본 관광지 삭제",
    responses={200: {"model": Envelope[OkOut], "description": "성공", **example({"ok": True})},
               **errors("401", "429")},
)
async def clear_recent(user: dict = Depends(current_user)):
    """최근 본 관광지를 전부 삭제한다. 개별 삭제 API 는 없다."""
    await db.clear_recent(user["id"])
    return {"ok": True}
