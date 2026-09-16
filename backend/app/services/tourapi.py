from __future__ import annotations

import re

from app.core.config import settings
from app.services import client

TYPE_ALL = ["12", "14", "15", "25", "28", "32", "38", "39"]


def split_signgu(tour_cd: str) -> tuple[str, str]:
    return tour_cd[:2], tour_cd[2:]


def ldong_params(tour_cd: str) -> dict:
    """법정동 코드 파라미터. 광역시 상위 코드(11000 처럼 뒤가 000)는 시도 단위로 조회한다."""
    regn, sig = split_signgu(tour_cd)
    out = {"lDongRegnCd": regn}
    if sig and sig != "000":
        out["lDongSignguCd"] = sig
    return out


def safe_float(v) -> float | None:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def strip_html(s: str | None) -> str:
    if not s:
        return ""
    return re.sub(r"<[^>]+>", "", s).strip()


def normalize(row: dict) -> dict:
    return {
        "content_id": row.get("contentid"),
        "content_type_id": row.get("contenttypeid"),
        "title": row.get("title"),
        "addr1": row.get("addr1") or "",
        "addr2": row.get("addr2") or "",
        "tel": row.get("tel") or "",
        "image": row.get("firstimage") or row.get("firstimage2") or "",
        "mapx": safe_float(row.get("mapx")),
        "mapy": safe_float(row.get("mapy")),
        "tour_cd": (row.get("lDongRegnCd") or "") + (row.get("lDongSignguCd") or ""),
        "lcls1": row.get("lclsSystm1") or "",
        "lcls2": row.get("lclsSystm2") or "",
        "lcls3": row.get("lclsSystm3") or "",
    }


async def search_keyword(
    keyword: str,
    tour_cd: str | None = None,
    *,
    rows: int = 20,
    content_type_id: str | None = None,
    session_id: str | None = None,
) -> list[dict]:
    params: dict = {"keyword": keyword, "numOfRows": rows, "pageNo": 1}
    if tour_cd:
        params.update(ldong_params(tour_cd))
    if content_type_id:
        params["contentTypeId"] = content_type_id

    items, _ = await client.call(
        "KorService2/searchKeyword2",
        params,
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    return [normalize(r) for r in items]


async def area_based_list(
    tour_cd: str,
    *,
    rows: int = 100,
    arrange: str | None = None,
    content_type_id: str | None = None,
    lcls1: str | None = None,
    lcls2: str | None = None,
    lcls3: str | None = None,
    max_pages: int = 8,
    session_id: str | None = None,
) -> list[dict]:
    params: dict = ldong_params(tour_cd)
    if arrange:
        params["arrange"] = arrange
    if content_type_id:
        params["contentTypeId"] = content_type_id
    if lcls1:
        params["lclsSystm1"] = lcls1
    if lcls2:
        params["lclsSystm2"] = lcls2
    if lcls3:
        params["lclsSystm3"] = lcls3

    items = await client.call_all(
        "KorService2/areaBasedList2",
        params,
        page_size=rows,
        max_pages=max_pages,
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    return [normalize(r) for r in items]


async def area_based_count(tour_cd: str, session_id: str | None = None) -> int:
    _, total = await client.call(
        "KorService2/areaBasedList2",
        {**ldong_params(tour_cd), "numOfRows": 1, "pageNo": 1},
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    return total


async def detail_common(content_id: str, session_id: str | None = None) -> dict | None:
    items, _ = await client.call(
        "KorService2/detailCommon2",
        {"contentId": content_id, "numOfRows": 1, "pageNo": 1},
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    if not items:
        return None
    row = items[0]
    out = normalize(row)
    out["overview"] = strip_html(row.get("overview"))
    out["homepage"] = strip_html(row.get("homepage"))
    out["zipcode"] = row.get("zipcode") or ""
    return out


_INTRO_LABELS = {
    "usetime": "이용시간",
    "restdate": "휴무일",
    "parking": "주차",
    "infocenter": "문의",
    "usefee": "입장료",
    "expguide": "체험안내",
    "chkpet": "반려동물",
    "chkbabycarriage": "유모차",
    "chkcreditcard": "카드결제",
    "useseason": "이용시기",
    "accomcount": "수용인원",
    "usetimeculture": "이용시간",
    "restdateculture": "휴무일",
    "parkingculture": "주차",
    "infocenterculture": "문의",
    "usefeeculture": "입장료",
}


async def detail_intro(
    content_id: str, content_type_id: str, session_id: str | None = None
) -> list[dict]:
    items, _ = await client.call(
        "KorService2/detailIntro2",
        {
            "contentId": content_id,
            "contentTypeId": content_type_id,
            "numOfRows": 1,
            "pageNo": 1,
        },
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    if not items:
        return []
    row = items[0]
    out = []
    for key, label in _INTRO_LABELS.items():
        val = strip_html(row.get(key))
        if val:
            out.append({"label": label, "value": val})
    return out


_NURI = {
    "Type1": "공공누리 제1유형 (출처표시)",
    "Type2": "공공누리 제2유형 (출처표시·상업적 이용금지)",
    "Type3": "공공누리 제3유형 (출처표시·변경금지)",
    "Type4": "공공누리 제4유형 (출처표시·상업적 이용금지·변경금지)",
}


async def detail_images(content_id: str, session_id: str | None = None) -> list[dict]:
    items, _ = await client.call(
        "KorService2/detailImage2",
        {"contentId": content_id, "imageYN": "Y", "numOfRows": 20, "pageNo": 1},
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    out = []
    for r in items:
        url = r.get("originimgurl") or r.get("smallimageurl")
        if url:
            out.append(
                {
                    "url": url,
                    "small": r.get("smallimageurl") or url,
                    "name": r.get("imgname") or "",
                    "copyright": _NURI.get(r.get("cpyrhtDivCd"), ""),
                }
            )
    return out


async def search_festival(
    tour_cd: str | None, start_ymd: str, *, rows: int = 50, session_id: str | None = None
) -> list[dict]:
    params: dict = {"eventStartDate": start_ymd, "numOfRows": rows, "pageNo": 1}
    if tour_cd:
        params.update(ldong_params(tour_cd))
    items, _ = await client.call(
        "KorService2/searchFestival2",
        params,
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    out = []
    for r in items:
        n = normalize(r)
        n["event_start"] = r.get("eventstartdate") or ""
        n["event_end"] = r.get("eventenddate") or ""
        out.append(n)
    return out


_PET_LABELS = {
    "acmpyTypeCd": "동반 구분",
    "acmpyPsblCpam": "동반 가능 동물",
    "relaAcdntRiskMtr": "안전 관련 사항",
    "relaPosesFclty": "관련 구비 시설",
    "relaFrnshPrdlst": "비치 품목",
    "relaRntlPrdlst": "대여 품목",
    "relaPurcPrdlst": "구매 가능 품목",
    "etcAcmpyInfo": "기타 동반 정보",
}


async def pet_tour_map(session_id: str | None = None) -> dict[str, str]:
    rows = await client.call_all(
        "KorService2/detailPetTour2",
        {},
        page_size=1000,
        max_pages=12,
        ttl=86400,
        session_id=session_id,
    )
    return {r["contentid"]: r.get("acmpyTypeCd") or "" for r in rows if r.get("contentid")}


async def detail_pet(content_id: str, session_id: str | None = None) -> list[dict]:
    items, _ = await client.call(
        "KorService2/detailPetTour2",
        {"contentId": content_id, "numOfRows": 1, "pageNo": 1},
        ttl=settings.upstream_cache_ttl_detail,
        session_id=session_id,
    )
    if not items:
        return []
    row = items[0]
    return [
        {"label": label, "value": strip_html(str(row.get(key) or ""))}
        for key, label in _PET_LABELS.items()
        if row.get(key)
    ]


async def ldong_codes(regn_cd: str | None = None) -> list[dict]:
    params: dict = {"numOfRows": 100, "pageNo": 1}
    if regn_cd:
        params["lDongRegnCd"] = regn_cd
    items, _ = await client.call("KorService2/ldongCode2", params, ttl=86400)
    return [{"code": r.get("code"), "name": r.get("name")} for r in items]


async def lcls_codes() -> list[dict]:
    items, _ = await client.call(
        "KorService2/lclsSystmCode2", {"numOfRows": 100, "pageNo": 1}, ttl=86400
    )
    return [{"code": r.get("code"), "name": r.get("name")} for r in items]
