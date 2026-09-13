from __future__ import annotations

from datetime import date, timedelta

from app.core.config import settings
from app.services import client


def lagged(days_back: int | None = None) -> str:
    d = date.today() - timedelta(days=days_back or settings.visitor_lag_days)
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


async def visitors(crowd_cd: str, weeks: int = 4, session_id=None) -> dict:
    weeks = max(1, min(int(weeks or 4), 52))
    end = date.today() - timedelta(days=settings.visitor_lag_days)
    start = end - timedelta(weeks=weeks)
    rows = await client.call_all(
        "DataLabService/locgoRegnVisitrDDList",
        {"startYmd": start.strftime("%Y%m%d"), "endYmd": end.strftime("%Y%m%d")},
        page_size=1000,
        max_pages=40,
        ttl=86400,
        session_id=session_id,
    )
    mine = [r for r in rows if r.get("signguCode") == crowd_cd]
    if not mine:
        return {"status": "no_data", "items": [], "data_through": end.isoformat()}

    by_day: dict[str, dict] = {}
    for r in mine:
        ymd = r.get("baseYmd") or ""
        d = f"{ymd[0:4]}-{ymd[4:6]}-{ymd[6:8]}"
        try:
            num = float(r.get("touNum") or 0)
        except ValueError:
            num = 0.0
        slot = by_day.setdefault(d, {"date": d, "total": 0.0})
        slot["total"] += num
        slot[VISITOR_KEY.get(r.get("touDivNm"), "other")] = round(num)

    items = sorted(by_day.values(), key=lambda x: x["date"])
    for i in items:
        i["total"] = round(i["total"])
    return {
        "status": "ok",
        "signgu_nm": mine[0].get("signguNm"),
        "items": items,
        "data_through": end.isoformat(),
        "note": "통신 데이터 기반이며 두 달쯤 지연된 값입니다",
    }
