from __future__ import annotations

import asyncio
import re
from collections import Counter
from app.core import clock
from app.core.config import settings
from app.core.errors import NotFound, QuotaExceeded
from app.repository import db
from app.services import (
    area, crowding, datalab, embedding, matcher, recommender, tourapi, trend,
)

SOURCE = "출처: ⓒ한국관광공사"

VISIT_TYPES = {"12", "14", "15", "25", "28", "38"}

PLACE_TYPES = {
    "관광지": "12", "문화시설": "14", "축제공연행사": "15", "여행코스": "25",
    "레포츠": "28", "숙박": "32", "쇼핑": "38", "음식점": "39",
}

CATEGORY_FILTER: dict[str, dict] = {
    "자연관광": {"lcls1": "NA"},
    "역사관광": {"lcls1": "HS"},
    "문화관광": {"lcls1": "VE"},
    "체험관광": {"lcls1": "EX"},
    "레저스포츠": {"lcls1": "LS"},
    "축제공연행사": {"lcls1": "EV"},
    "쇼핑": {"lcls1": "SH"},
    "음식": {"lcls1": "FD"},
    "숙박": {"lcls1": "AC"},
    "캠핑": {"lcls2": "AC05"},
    "웰니스": {"lcls2": "EX05"},
    "관광지": {"content_type_id": "12"},
    "여행코스": {"content_type_id": "25"},
}

CATEGORY_ALIAS = {
    "음식점": "음식", "문화시설": "문화관광", "레포츠": "레저스포츠",
    "야영장": "캠핑", "캠핑장": "캠핑",
    "의료": "웰니스", "헬스케어": "웰니스",
}


def category_filter(category: str) -> dict | None:
    name = CATEGORY_ALIAS.get(category, category)
    return CATEGORY_FILTER.get(name)


async def resolve_area(query: str) -> dict:
    r = await area.resolve(query)
    if r["status"] != "not_found":
        return r
    words = (query or "").split()
    if not words:
        return r
    last = words[-1]
    bare = re.sub(r"[읍면동리]$", "", last) if len(last) > 2 else last
    for kw in dict.fromkeys([query, last, bare]):
        try:
            found = await tourapi.search_keyword(kw, rows=20)
        except Exception:
            return r
        codes = [f["tour_cd"] for f in found if f.get("tour_cd")]
        if not codes:
            continue
        top, n = Counter(codes).most_common(1)[0]
        if n < 3 or n * 2 < len(codes):
            continue
        a = await db.get_area(top)
        if a:
            return {
                "status": "ok",
                **a,
                "note": f"'{kw}' 일대는 {a['label']} 기준으로 안내합니다",
            }
    return r


async def children_of(a: dict) -> list[dict]:
    if area.is_metro_parent(a):
        return await db.child_areas(a["signgu_nm"], area_cd=a["area_cd"])
    return await db.child_areas(a["signgu_nm"])


async def area_of(code: str) -> dict:
    a = await db.get_area(code)
    if a is None:
        await area.ensure_loaded()
        a = await db.get_area(code)
    if a is None:
        raise NotFound("모르는 지역 코드입니다")
    return a


async def tourapi_count(a: dict, session_id=None) -> int | None:
    codes = [a["tour_cd"]]
    if a.get("merged_from") or area.is_metro_parent(a):
        children = await children_of(a)
        codes = [c["tour_cd"] for c in children if c["tour_cd"]] or codes

    total = 0
    for code in codes:
        try:
            total += await tourapi.area_based_count(code, session_id=session_id)
        except Exception:
            return None
    return total


async def decorate(items: list[dict]) -> list[dict]:
    lookup = await db.areas_by_code({it.get("tour_cd") for it in items})
    for it in items:
        a = lookup.get(it.get("tour_cd") or "")
        it["signgu_cd"] = a["crowd_cd"] if a else it.get("tour_cd")
        it["signgu_nm"] = a["signgu_nm"] if a else ""
    return items


def norm(s: str) -> str:
    return re.sub(r"\s", "", s or "")


async def from_mapping(name: str, area_row: dict) -> dict | None:
    mapping = await db.get_mapping(area_row["crowd_cd"])
    if not mapping:
        return None

    key = norm(name)
    hits = [
        (nm, v) for nm, v in mapping.items()
        if v.get("content_id")
        and (key == norm(nm) or key == norm(v.get("matched_title") or "")
             or (len(key) >= 2 and key in norm(nm)))
    ]
    if len(hits) != 1:
        return None

    nm, v = hits[0]
    return {
        "status": "ok",
        "confident": True,
        "items": [
            {
                "content_id": v["content_id"],
                "title": v.get("matched_title") or nm,
                "addr1": f"{area_row['sido_nm']} {area_row['signgu_nm']}",
                "signgu_cd": area_row["crowd_cd"],
                "signgu_nm": area_row["signgu_nm"],
                "content_type_id": None,
            }
        ],
        "from": "mapping",
        "source": SOURCE,
    }


async def find_attraction(name: str, signgu_cd: str | None = None, session_id=None) -> dict:
    area_row = await area_of(signgu_cd) if signgu_cd else None
    tour_cd = area_row["tour_cd"] if area_row else None

    if area_row:
        hit = await from_mapping(name, area_row)
        if hit:
            return hit

    items: list[dict] = []
    try:
        items = await tourapi.search_keyword(name, tour_cd, rows=15, session_id=session_id)

        if not items and tour_cd:
            found = await tourapi.search_keyword(name, None, rows=20, session_id=session_id)
            items = [f for f in found if matcher.same_area(f.get("tour_cd"), tour_cd)]
    except QuotaExceeded:
        return {
            "status": "no_data",
            "items": [],
            "message": "관광지 검색 한도를 오늘 다 썼어요. 지역 전체 현황은 볼 수 있어요.",
            "signgu_cd": signgu_cd,
            "signgu_nm": area_row["signgu_nm"] if area_row else "",
        }

    if not items:
        return {
            "status": "not_found",
            "items": [],
            "hint": "어떤 관광지를 찾으시나요? 지역명이나 정확한 이름으로 다시 알려주세요",
        }

    key = re.sub(r"\s", "", name)
    visit = [i for i in items if i.get("content_type_id") in VISIT_TYPES]
    exact = [i for i in visit if re.sub(r"\s", "", i["title"] or "") == key]
    partial = [i for i in visit if key in re.sub(r"\s", "", i["title"] or "")]

    strong = exact or partial
    ordered = strong + [i for i in items if i not in strong]

    return {
        "status": "ok",
        "confident": len(exact) == 1 or len(partial) == 1,
        "items": await decorate(ordered[:10]),
        "source": SOURCE,
    }


async def with_child_fallback(a: dict, fetch) -> list[dict]:
    """상위 행정구역이면 하위 시군구를 돌며 모은다.

    서울·부산 같은 광역시 상위 행은 관광정보 쪽 코드가 없어 바로 조회할 수 없고,
    '청주시'처럼 구를 거느린 시는 상위 코드로 먼저 시도한 뒤 비면 하위로 내려간다.
    """
    if area.is_metro_parent(a):
        items: list[dict] = []
        for c in await children_of(a):
            if c["tour_cd"]:
                items += await fetch(c["tour_cd"])
        return items
    items = await fetch(a["tour_cd"])
    if not items:
        for c in await children_of(a):
            if c["tour_cd"]:
                items += await fetch(c["tour_cd"])
    return items


async def region_places(
    a: dict, *, content_type_id=None, lcls1=None, lcls2=None,
    arrange=None, max_pages=1, rows=50, session_id=None,
) -> list[dict]:
    return await with_child_fallback(
        a,
        lambda cd: tourapi.area_based_list(
            cd, content_type_id=content_type_id, lcls1=lcls1, lcls2=lcls2,
            rows=rows, max_pages=max_pages, arrange=arrange, session_id=session_id,
        ),
    )


async def list_places(
    signgu_cd: str, category: str, limit: int = 10, session_id=None
) -> dict:
    a = await area_of(signgu_cd)
    f = category_filter(category)
    if f is None:
        return {
            "status": "not_found",
            "items": [],
            "hint": f"'{category}' 갈래는 없어요. "
                    f"{', '.join(CATEGORY_FILTER)} 중에서 물어봐 주세요",
        }

    try:
        items = await region_places(a, arrange="Q", session_id=session_id, **f)
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "items": [], "message": e.message}

    if not items:
        return {
            "status": "no_data",
            "items": [],
            "signgu_nm": a["signgu_nm"],
            "message": f"{a['signgu_nm']}의 {category} 정보가 아직 없어요",
        }
    return {
        "status": "ok",
        "category": category,
        "signgu_nm": a["signgu_nm"],
        "items": await decorate(items[:limit]),
        "source": SOURCE,
    }


async def find_pet_friendly(
    signgu_cd: str, limit: int = 8, session_id=None, category: str | None = None
) -> dict:
    a = await area_of(signgu_cd)
    filters: list[dict] = [{"content_type_id": t} for t in ("12", "14", "28")]
    if category:
        picked = category_filter(category)
        if picked:
            filters = [picked]
    hits, seen = [], set()
    try:
        pets = await tourapi.pet_tour_map(session_id=session_id)
        for f in filters:
            for i in await region_places(
                a, arrange="Q", max_pages=4, session_id=session_id, **f
            ):
                t = pets.get(i["content_id"])
                if t and "불가" not in t and i["content_id"] not in seen:
                    seen.add(i["content_id"])
                    hits.append({**i, "note": f"반려동물 {t}"})
            if len(hits) >= limit:
                break
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "items": [], "message": e.message}
    if not hits:
        return {
            "status": "no_data",
            "items": [],
            "signgu_nm": a["signgu_nm"],
            "message": f"{a['signgu_nm']}에서 반려동물 동반 가능으로 등록된 곳을 찾지 못했어요",
        }
    return {
        "status": "ok",
        "signgu_nm": a["signgu_nm"],
        "items": await decorate(hits[:limit]),
        "source": SOURCE,
    }


async def attraction_images(content_id: str, session_id=None) -> dict:
    try:
        items = await tourapi.detail_images(content_id, session_id=session_id)
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "items": [], "message": e.message}
    return {"status": "ok" if items else "no_data", "items": items, "source": SOURCE}


async def attraction_pet(content_id: str, session_id=None) -> dict:
    try:
        items = await tourapi.detail_pet(content_id, session_id=session_id)
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "items": [], "message": e.message}
    return {"status": "ok" if items else "no_data", "items": items, "source": SOURCE}


def fmt_ymd(ymd: str) -> str:
    return f"{ymd[0:4]}-{ymd[4:6]}-{ymd[6:8]}" if len(ymd) == 8 else ymd


async def list_festivals(
    signgu_cd: str, date_from: str | None = None, limit: int = 10, session_id=None
) -> dict:
    a = await area_of(signgu_cd)
    start = (date_from or clock.today_str()).replace("-", "")

    try:
        items = await with_child_fallback(
            a, lambda cd: tourapi.search_festival(cd, start, session_id=session_id)
        )
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "items": [], "message": e.message}

    items.sort(key=lambda i: i.get("event_start") or "9")
    for i in items:
        i["period"] = f"{fmt_ymd(i['event_start'])} ~ {fmt_ymd(i['event_end'])}".strip(" ~")

    if not items:
        return {
            "status": "no_data",
            "items": [],
            "signgu_nm": a["signgu_nm"],
            "message": f"{a['signgu_nm']}에 예정된 행사 정보가 아직 없어요",
        }
    return {
        "status": "ok",
        "signgu_nm": a["signgu_nm"],
        "items": await decorate(items[:limit]),
        "source": SOURCE,
    }


async def crowd_context(signgu_cd: str, session_id=None) -> tuple[dict, dict, dict]:
    a = await area_of(signgu_cd)
    by_name = (
        {}
        if area.is_metro_parent(a)
        else await crowding.fetch_signgu(a["crowd_cd"], session_id=session_id)
    )

    if not by_name:
        children = await children_of(a)
        if children:
            parts = await asyncio.gather(
                *[crowding.fetch_signgu(c["crowd_cd"], session_id=session_id) for c in children],
                return_exceptions=True,
            )
            merged: dict[str, list[dict]] = {}
            used = []
            for child, part in zip(children, parts):
                if isinstance(part, dict) and part:
                    merged.update(part)
                    used.append(child)
            if merged:
                by_name = merged
                a = {**a, "merged_from": [c["signgu_nm"] for c in used]}

    # 요청 경로에서는 몇 건만 매핑한다. 본격 매핑은 jobs.run name-map 배치가 한다.
    mapping = await matcher.ensure(
        a["crowd_cd"], a["tour_cd"], a["signgu_nm"], list(by_name.keys()),
        budget=settings.request_map_budget,
    )
    return a, by_name, mapping


async def reverse_map(
    cid: str, area_row: dict, by_name: dict, mapping: dict, session_id=None
) -> str | None:
    try:
        d = await tourapi.detail_common(cid, session_id=session_id)
    except Exception:
        return None
    if not d:
        return None
    free = [n for n in by_name if not (mapping.get(n) or {}).get("content_id")]
    hit = matcher.reverse_match(d.get("title") or "", free)
    if not hit:
        return None
    row = {
        "tats_nm": hit,
        "content_id": cid,
        "matched_title": d.get("title"),
        "match_method": "reverse",
        "confidence": 0.9,
        "image": d.get("image") or "",
    }
    await db.put_mapping(area_row["crowd_cd"], [row])
    mapping[hit] = row
    return hit


async def get_crowding(
    signgu_cd: str,
    content_ids: list[str] | None = None,
    date_from: str | None = None,
    days: int = 7,
    session_id=None,
) -> dict:
    days = max(1, min(days, settings.crowd_max_days))
    a, by_name, mapping = await crowd_context(signgu_cd, session_id)

    if not by_name:
        return {
            "status": "no_data",
            "signgu_nm": a["signgu_nm"],
            "message": "이 지역은 아직 집중률 데이터가 없어요",
            "items": [],
        }

    if not content_ids:
        agg = crowding.aggregate(by_name, date_from)
        sample_names = [q["name"] for q in (agg.get("samples") or {}).get("quiet", [])]
        if sample_names:
            mapping = await matcher.ensure(
                a["crowd_cd"], a["tour_cd"], a["signgu_nm"], sample_names,
                budget=settings.request_map_budget,
            )
        for bucket in (agg.get("samples") or {}).values():
            for q in bucket:
                m = mapping.get(q["name"]) or {}
                q["content_id"] = m.get("content_id")
                q["image"] = m.get("image") or ""
        quiet = (agg.get("samples") or {}).get("quiet")
        if quiet:
            agg["samples"]["quiet"] = [
                q for q in quiet if not matcher.delisted(mapping, q["name"])
            ]
        out = {
            "status": "ok",
            "signgu_cd": a["crowd_cd"],
            "signgu_nm": a["signgu_nm"],
            **agg,
            "coverage": {
                "tourapi_total": await tourapi_count(a, session_id),
                "with_crowd_data": len(by_name),
            },
            "source": SOURCE,
        }
        if a.get("merged_from"):
            out["merged_from"] = a["merged_from"]
        return out

    rev = matcher.by_content_id(mapping)
    items, unmatched = [], []
    for cid in content_ids:
        name = rev.get(cid)
        if not name or name not in by_name:
            name = await reverse_map(cid, a, by_name, mapping, session_id)
        if not name or name not in by_name:
            unmatched.append(cid)
            continue
        series = crowding.slice_series(by_name[name], date_from, days)
        m = mapping.get(name, {})
        items.append(
            {
                "content_id": cid,
                "name": name,
                "matched_title": m.get("matched_title"),
                "match_method": m.get("match_method"),
                "match_confidence": m.get("confidence"),
                "series": series,
                "summary": crowding.summarize(series),
                "available_days": len(by_name[name]),
            }
        )

    return {
        "status": "ok" if items else "no_data",
        "signgu_cd": a["crowd_cd"],
        "signgu_nm": a["signgu_nm"],
        "items": items,
        "unmatched": unmatched,
        "source": SOURCE,
    }


async def area_for_content(content_id: str, session_id=None) -> dict | None:
    crowd_cd = await db.mapping_area(content_id)
    if crowd_cd:
        return await db.get_area(crowd_cd)
    detail = await tourapi.detail_common(content_id, session_id=session_id)
    if not detail or not detail.get("tour_cd"):
        return None
    return await db.get_area(detail["tour_cd"])


async def crowd_for_content(
    content_id: str, days: int = 7, date_from: str | None = None, session_id=None
) -> dict:
    try:
        a = await area_for_content(content_id, session_id)
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "has_data": False, "series": [],
                "message": e.message}
    if a is None:
        return {"status": "not_found", "has_data": False, "series": []}
    signgu_cd = a["crowd_cd"]

    res = await get_crowding(signgu_cd, [content_id], date_from, days, session_id)
    hit = next((i for i in res.get("items", [])), None)
    if not hit:
        return {
            "status": "ok",
            "content_id": content_id,
            "has_data": False,
            "series": [],
            "message": "해당 관광지의 집중률 데이터가 아직 없어요. 지역 전체 현황을 볼까요?",
            "signgu_cd": signgu_cd,
            "signgu_nm": res.get("signgu_nm"),
            "source": SOURCE,
        }
    return {
        "status": "ok",
        "content_id": content_id,
        "matched_name": hit["name"],
        "match_method": hit["match_method"],
        "match_confidence": hit["match_confidence"],
        "series": hit["series"],
        "summary": hit["summary"],
        "available_days": hit["available_days"],
        "has_data": bool(hit["series"]),
        "signgu_cd": signgu_cd,
        "signgu_nm": res.get("signgu_nm"),
        "source": SOURCE,
    }


async def attraction_detail(content_id: str, session_id=None, include_pet: bool = False) -> dict:
    try:
        detail = await tourapi.detail_common(content_id, session_id=session_id)
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "message": e.message}
    if not detail:
        return {"status": "not_found"}
    intro = []
    if detail.get("content_type_id"):
        try:
            intro = await tourapi.detail_intro(
                content_id, detail["content_type_id"], session_id=session_id
            )
        except Exception:
            intro = []
    pet = []
    if include_pet:
        try:
            pet = await tourapi.detail_pet(content_id, session_id=session_id)
        except Exception:
            pet = []
    signgu = await db.get_area(detail.get("tour_cd") or "")
    return {
        "status": "ok",
        **detail,
        "signgu_cd": signgu["crowd_cd"] if signgu else None,
        "signgu_nm": signgu["signgu_nm"] if signgu else "",
        "sido_nm": signgu["sido_nm"] if signgu else "",
        "info": intro,
        "pet": pet,
        "source": SOURCE,
    }


ALTERNATIVES_MAX = 10


async def recommend_alternatives(
    content_id: str, date_on: str | None = None, limit: int = 5, session_id=None
) -> dict:
    limit = max(1, min(limit, ALTERNATIVES_MAX))
    a0 = await area_for_content(content_id, session_id)
    if a0 is None:
        return {"status": "not_found", "items": []}

    a, by_name, mapping = await crowd_context(a0["crowd_cd"], session_id)
    rev = matcher.by_content_id(mapping)

    try:
        base = dict(await tourapi.detail_common(content_id, session_id=session_id) or {})
    except QuotaExceeded:
        base = {}
    base["content_id"] = content_id
    base["tour_cd"] = base.get("tour_cd") or a0["tour_cd"]
    base["matched_name"] = rev.get(content_id)
    base.setdefault("title", base["matched_name"] or content_id)

    res = await recommender.alternatives(
        base, a["crowd_cd"], a["tour_cd"], a["signgu_nm"], by_name, mapping,
        on=date_on, limit=limit, session_id=session_id,
    )
    res["signgu_nm"] = a["signgu_nm"]
    res["source"] = SOURCE
    return res


async def interest_trend(
    names: list[str], weeks: int | None = None, signgu_nm: str = ""
) -> dict:
    short_to_display: dict[str, str] = {}
    short = []
    for n in names:
        s = matcher.short_name(n, signgu_nm)
        short.append(s)
        short_to_display.setdefault(s, n)
    res = await trend.fetch(short, weeks)
    for item in res.get("items", []):
        disp = short_to_display.get(item.get("name"))
        if disp:
            item["display_name"] = disp
    return res


async def area_overview(signgu_cd: str, date_on: str | None = None, session_id=None) -> dict:
    return await get_crowding(signgu_cd, None, date_on, 1, session_id)


async def area_visitors(signgu_cd: str, weeks: int = 4, session_id=None) -> dict:
    a = await area_of(signgu_cd)
    return await datalab.visitors(a["crowd_cd"], weeks, session_id)


async def build_vectors(signgu_cd: str, limit: int = 60) -> dict:
    a = await area_of(signgu_cd)
    by_name = await crowding.fetch_signgu(a["crowd_cd"])
    await matcher.ensure(a["crowd_cd"], a["tour_cd"], a["signgu_nm"], list(by_name.keys()),
                         budget=limit)
    res = await embedding.build_for_area(a["crowd_cd"], a["tour_cd"], limit)
    res["signgu_nm"] = a["signgu_nm"]
    return res


async def similar_attractions(content_id: str, limit: int = 5) -> dict:
    try:
        a = await area_for_content(content_id)
    except QuotaExceeded as e:
        return {"status": "quota_exceeded", "items": [], "message": e.message}
    if a is None:
        return {"status": "not_found", "items": []}
    items = await embedding.similar(content_id, a["crowd_cd"], limit=limit)
    return {
        "status": "ok" if items else "no_data",
        "items": items,
        "message": None if items else "이 지역은 아직 유사도 데이터가 없어요",
        "source": SOURCE,
    }


async def ask(question: str, session_id=None) -> dict:
    from app.agent.intent import parse_intent

    intent = parse_intent(question)
    out: dict = {"intent": intent, "cards": [], "source": SOURCE}

    if not intent["tokens"]:
        out["message"] = "혼잡도 확인이나 관광지 추천을 도와드릴 수 있어요. 어떤 지역이 궁금하세요?"
        return out

    await area.ensure_loaded()
    resolved, used_token, pending = None, None, None
    for cand in intent["area_candidates"]:
        r = await resolve_area(cand)
        if r["status"] == "ok":
            resolved, used_token = r, cand
            break
        if r["status"] == "ambiguous" and pending is None:
            pending = r

    if resolved is None and pending is not None:
        out["message"] = "어느 지역을 말씀하시는 건가요?"
        out["candidates"] = pending["candidates"]
        return out

    signgu_cd = resolved["signgu_cd"] if resolved else None
    if resolved:
        out["area"] = {k: resolved[k] for k in ("signgu_cd", "sido_nm", "signgu_nm", "label")}

    parts = (used_token or "").split()
    rest = [t for t in intent["tokens"] if t not in parts]
    attraction = max(rest, key=len) if rest else None

    if not attraction:
        if not signgu_cd:
            out["message"] = "지역명이나 관광지명을 알려주세요"
            return out
        ov = await area_overview(signgu_cd, intent.get("date"), session_id)
        out["cards"].append({"type": "area_overview", "payload": ov})
        return out

    found = await find_attraction(attraction, signgu_cd, session_id)
    if found["status"] != "ok":
        if signgu_cd:
            ov = await area_overview(signgu_cd, intent.get("date"), session_id)
            out["cards"].append({"type": "area_overview", "payload": ov})
            out["message"] = f"'{attraction}'을 못 찾아서 {resolved['signgu_nm']} 전체 현황을 보여드립니다."
            return out
        out["message"] = found.get("hint") or found.get("message") or "관광지를 찾지 못했어요"
        return out

    if len(found["items"]) > 1 and not signgu_cd:
        out["message"] = "어떤 곳을 말씀하시는 건가요?"
        out["candidates"] = [
            {"content_id": i["content_id"], "label": f"{i['title']} ({i['addr1']})"}
            for i in found["items"][:5]
        ]
        return out

    target = found["items"][0]
    if not resolved and target.get("signgu_cd"):
        out["area"] = {
            "signgu_cd": target["signgu_cd"],
            "signgu_nm": target.get("signgu_nm", ""),
        }
    out["cards"].append({"type": "attraction", "payload": target})

    crowd = await crowd_for_content(
        target["content_id"], intent.get("days", 7), intent.get("date"), session_id
    )
    out["cards"].append({"type": "crowd", "payload": crowd})

    if intent["want_alternatives"] or crowd.get("has_data"):
        signgu_nm = out.get("area", {}).get("signgu_nm", "")
        alt, tr = await asyncio.gather(
            recommend_alternatives(target["content_id"], intent.get("date"), 5, session_id),
            interest_trend([target["title"]], signgu_nm=signgu_nm),
            return_exceptions=True,
        )
        if isinstance(alt, dict):
            out["cards"].append({"type": "alternatives", "payload": alt})
        if isinstance(tr, dict):
            out["cards"].append({"type": "interest", "payload": tr})

    return out
