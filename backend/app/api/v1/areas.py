from __future__ import annotations

from datetime import date as _date

from fastapi import APIRouter, Depends, HTTPException, Path, Query

from app.core.response import EnvelopeRoute
from app.core.deps import current_user
from app.repository import db
from app.schemas.area import AreaListOut, OverviewOut, ResolveOut, VisitorsOut
from app.schemas.common import Envelope, errors, example
from app.services import area, usecase

router = APIRouter(prefix="/areas", tags=["areas"], dependencies=[Depends(current_user)],
                   route_class=EnvelopeRoute)

CD = Path(description="시군구 코드. /areas 또는 /areas/resolve 응답의 signgu_cd", examples=["44825"])
DATE_Q = Query(default=None, description="YYYY-MM-DD. 비우면 오늘", examples=["2026-09-06"])

_OVERVIEW_EX = {
    "status": "ok", "signgu_cd": "44825", "signgu_nm": "태안군", "date": "2026-09-06",
    "summary": {"crowded": 3, "normal": 11, "quiet": 22},
    "samples": {
        "crowded": [{"name": "꽃지해수욕장", "rate": 88.0, "content_id": "126165", "image": ""}],
        "normal": [{"name": "안면도자연휴양림", "rate": 55.1, "content_id": "125452", "image": ""}],
        "quiet": [{"name": "운여해변", "rate": 28.4, "content_id": "126266", "image": ""}],
    },
    "coverage": {"tourapi_total": 214, "with_crowd_data": 36},
    "source": "출처: ⓒ한국관광공사",
}


def check_date(value: str | None) -> str | None:
    if value is not None:
        try:
            _date.fromisoformat(value)
        except ValueError:
            raise HTTPException(422, "날짜 형식은 YYYY-MM-DD 여야 합니다")
    return value


@router.get(
    "",
    summary="시군구 목록 조회",
    responses={200: {"model": Envelope[AreaListOut], "description": "성공", **example(
        {"count": 268, "sido": [
            {"sido_nm": "충청남도", "items": [{"signgu_cd": "44825", "signgu_nm": "태안군"},
                                          {"signgu_cd": "44210", "signgu_nm": "보령시"}]},
            {"sido_nm": "강원특별자치도", "items": [{"signgu_cd": "51820", "signgu_nm": "고성군"}]}]})},
        **errors("401", "429")},
)
async def list_areas():
    """시도별로 묶은 시군구 전체 목록. 기준정보라 클라이언트에서 캐시해도 된다."""
    await area.ensure_loaded()
    rows = await db.all_areas()
    groups: dict[str, list] = {}
    for r in rows:
        groups.setdefault(r["sido_nm"], []).append(
            {"signgu_cd": r["signgu_cd"], "signgu_nm": r["signgu_nm"]}
        )
    return {
        "count": len(rows),
        "sido": [{"sido_nm": k, "items": v} for k, v in groups.items()],
    }


@router.get(
    "/resolve",
    summary="지역명으로 코드 조회",
    responses={200: {"model": Envelope[ResolveOut], "description": "성공", **example(
        {"status": "ok", "signgu_cd": "44825", "signgu_nm": "태안군", "sido_nm": "충청남도",
         "label": "충청남도 태안군", "tour_cd": "34_14", "crowd_cd": "44825"})},
        **errors("401", "422", "429")},
)
async def resolve(q: str = Query(min_length=1, description="지역명",
                                 examples=["태안"])):
    """지역명을 시군구 코드로 변환한다.

    이름이 겹치는 지역(강원 고성, 경남 고성)은 status 가 ambiguous 이고 candidates 가
    함께 온다. 임의로 첫 후보를 선택하면 다른 지역이 열린다.

    코드표에 없는 읍면동은 해당 이름의 관광지가 집중된 시군구로 추정하고 note 를
    붙인다. 과반이 한 시군구가 아니면 추정하지 않는다.
    """
    return await usecase.resolve_area(q)


@router.get(
    "/{signgu_cd}/overview",
    summary="지역 혼잡 현황 조회",
    responses={200: {"model": Envelope[OverviewOut], "description": "성공",
                     **example(_OVERVIEW_EX)},
               **errors("401", "404", "422", "429", "502", "503",
                 messages={"404": "모르는 지역 코드입니다"})},
)
async def overview(signgu_cd: str = CD, date: str | None = DATE_Q):
    """지정일 기준 등급별 관광지 수와 한적한 곳 표본. 지역 화면의 기본 조회다.

    coverage 는 관광정보 등록 수 대비 혼잡도 자료 보유 수다. 혼잡도 집계 대상이 아닌
    시군구가 존재하며 그 경우 status 는 no_data 다.

    이 조회 한 번에 상류 호출이 두세 건 나간다.
    """
    return await usecase.area_overview(signgu_cd, check_date(date))


@router.get(
    "/{signgu_cd}/crowding",
    summary="지역 혼잡도 조회",
    responses={200: {"model": Envelope[OverviewOut], "description": "성공",
                     **example(_OVERVIEW_EX)},
               **errors("401", "404", "422", "429", "502", "503",
                 messages={"404": "모르는 지역 코드입니다"})},
)
async def crowding(signgu_cd: str = CD, date: str | None = DATE_Q):
    """현황 집계 없이 혼잡도 원자료만 조회한다. 웹 화면은 overview 만 사용한다."""
    return await usecase.get_crowding(signgu_cd, None, check_date(date), 1)


@router.get(
    "/{signgu_cd}/visitors",
    summary="지역 방문자 추이 조회",
    responses={200: {"model": Envelope[VisitorsOut], "description": "성공", **example(
        {"status": "ok", "signgu_nm": "태안군",
         "items": [{"date": "2026-06-15", "total": 41233, "local": 18820, "outsider": 22413},
                   {"date": "2026-06-22", "total": 39810, "local": 17904, "outsider": 21906}],
         "data_through": "2026-06-23",
         "note": "통신 데이터 기반이며 두 달쯤 지연된 값입니다"})},
        **errors("401", "404", "422", "429", "502", "503",
                 messages={"404": "모르는 지역 코드입니다"})},
)
async def visitors(
    signgu_cd: str = CD,
    weeks: int = Query(default=4, ge=1, le=52, description="조회 기간(주)"),
):
    """주 단위 방문자 추이.

    통신 데이터 기반이라 원천이 약 두 달 지연된다. data_through 가 자료의 마지막
    날짜이며 화면에 함께 표시해야 한다.
    """
    return await usecase.area_visitors(signgu_cd, weeks)
