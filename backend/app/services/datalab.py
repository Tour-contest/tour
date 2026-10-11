from __future__ import annotations

from datetime import date, timedelta

from app.core import clock
from app.core.config import settings
from app.repository import db
from app.services import client


def lagged(days_back: int | None = None) -> str:
    d = clock.today() - timedelta(days=days_back or settings.visitor_lag_days)
    return d.strftime("%Y%m%d")


async def signgu_list(ymd: str | None = None) -> list[dict]:
    day = ymd or lagged()
    rows = await client.call_all(
        "DataLabService/locgoRegnVisitrDDList",
        {"startYmd": day, "endYmd": day},
        page_size=1000,
        max_pages=6,
        ttl=86400,
    )
    seen: dict[str, str] = {}
    for r in rows:
        code, name = r.get("signguCode"), r.get("signguNm")
        if code and name:
            seen.setdefault(code, name)
    return [{"code": c, "name": n} for c, n in seen.items()]


async def sido_list(ymd: str | None = None) -> list[dict]:
    day = ymd or lagged()
    rows = await client.call_all(
        "DataLabService/metcoRegnVisitrDDList",
        {"startYmd": day, "endYmd": day},
        page_size=500,
        max_pages=3,
        ttl=86400,
    )
    seen: dict[str, str] = {}
    for r in rows:
        code, name = r.get("areaCode"), r.get("areaNm")
        if code and name:
            seen.setdefault(code, name)
    return [{"code": c, "name": n} for c, n in seen.items()]


VISITOR_KEY = {"현지인(a)": "local", "외지인(b)": "outsider", "외국인(c)": "foreigner"}

ROWS_PER_DAY = 800  # 전국 시군구 × 관광객 구분 3종. 페이지 수 계산용 여유치


def ymd(d: date) -> str:
    return d.strftime("%Y%m%d")


def spans(days: list[date]) -> list[tuple[date, date]]:
    """연속된 날짜를 [시작, 끝] 구간으로 묶는다."""
    out: list[tuple[date, date]] = []
    for d in sorted(days):
        if out and out[-1][1] + timedelta(days=1) == d:
            out[-1] = (out[-1][0], d)
        else:
            out.append((d, d))
    return out


async def fetch_span(start: date, end: date, session_id=None) -> list[dict]:
    """전국 방문자수를 받아 저장할 행으로 바꾼다. 원천 파라미터에 지역 필터가 없다."""
    days = (end - start).days + 1
    rows = await client.call_all(
        "DataLabService/locgoRegnVisitrDDList",
        {"startYmd": ymd(start), "endYmd": ymd(end)},
        page_size=1000,
        max_pages=-(-days * ROWS_PER_DAY // 1000) + 1,
        ttl=None,
        session_id=session_id,
    )
    by_key: dict[tuple[str, str], dict] = {}
    for r in rows:
        code, base = r.get("signguCode"), r.get("baseYmd") or ""
        if not code or len(base) != 8:
            continue
        try:
            num = float(r.get("touNum") or 0)
        except ValueError:
            num = 0.0
        day = f"{base[0:4]}-{base[4:6]}-{base[6:8]}"
        slot = by_key.setdefault((code, day), {
            "signgu_cd": code, "day": date.fromisoformat(day),
            "signgu_nm": r.get("signguNm"), "local": 0, "outsider": 0,
            "foreigner": 0, "total": 0,
        })
        kind = VISITOR_KEY.get(r.get("touDivNm"))
        if kind:
            slot[kind] += round(num)
        slot["total"] += round(num)
    return list(by_key.values())


async def ensure_visitors(start: date, end: date, session_id=None) -> bool:
    """[start, end] 중 DB 에 없는 날짜만 상류에서 받아 저장한다. 전부 채웠으면 True."""
    have = await db.visitor_days(start, end)
    missing = [start + timedelta(days=i) for i in range((end - start).days + 1)
               if start + timedelta(days=i) not in have]
    if not missing:
        return True
    complete = True
    for a, b in spans(missing):
        try:
            rows = await fetch_span(a, b, session_id)
        except Exception:
            complete = False
            continue
        got = {r["day"] for r in rows}
        if any(d not in got for d in (a + timedelta(days=i) for i in range((b - a).days + 1))):
            complete = False
        await db.put_visitors(rows)
    return complete


async def visitors(crowd_cd: str, weeks: int = 4, session_id=None) -> dict:
    weeks = max(1, min(int(weeks or 4), settings.visitor_weeks_max))
    end = clock.today() - timedelta(days=settings.visitor_lag_days)
    start = end - timedelta(weeks=weeks) + timedelta(days=1)

    complete = await ensure_visitors(start, end, session_id)
    items = await db.visitors_between(crowd_cd, start, end)
    if not items:
        return {"status": "no_data", "items": [], "data_through": end.isoformat(),
                "partial": not complete}

    signgu_nm = items[0].pop("signgu_nm", None)
    for i in items:
        i.pop("signgu_nm", None)
    return {
        "status": "ok",
        "signgu_nm": signgu_nm,
        "items": items,
        "data_through": end.isoformat(),
        "partial": not complete,
        "note": "통신 데이터 기반이며 두 달쯤 지연된 값입니다",
    }
