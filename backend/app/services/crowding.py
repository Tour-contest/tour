from __future__ import annotations

from datetime import date, datetime, timedelta

from app.core import clock
from app.core.config import settings
from app.services import client

_WEEKDAY = ["월", "화", "수", "목", "금", "토", "일"]

LEVEL_KEY = {"혼잡": "crowded", "보통": "normal", "한적": "quiet"}


def grade(rate: float) -> str:
    if rate >= settings.crowd_threshold_high:
        return "혼잡"
    if rate >= settings.crowd_threshold_low:
        return "보통"
    return "한적"


def fmt(ymd: str) -> str:
    return f"{ymd[0:4]}-{ymd[4:6]}-{ymd[6:8]}"


def codes_of(a: dict) -> list[str]:
    """집중률을 물어볼 코드. 통합으로 코드가 바뀐 지역은 새 코드, 옛 코드 순으로 둘 다 본다."""
    return [c for c in (a["crowd_cd"], a.get("legacy_cd")) if c]


async def has_data(signgu_cd: str) -> bool:
    _, total = await client.call(
        "TatsCnctrRateService/tatsCnctrRatedList",
        {"areaCd": signgu_cd[:2], "signguCd": signgu_cd, "numOfRows": 1, "pageNo": 1},
        ttl=86400,
    )
    return total > 0


async def has_data_for(a: dict) -> bool:
    for cd in codes_of(a):
        if await has_data(cd):
            return True
    return False


async def fetch_area(a: dict, session_id: str | None = None) -> dict[str, list[dict]]:
    for cd in codes_of(a):
        by_name = await fetch_signgu(cd, session_id=session_id)
        if by_name:
            return by_name
    return {}


async def fetch_signgu(signgu_cd: str, session_id: str | None = None) -> dict[str, list[dict]]:
    rows = await client.call_all(
        "TatsCnctrRateService/tatsCnctrRatedList",
        {"areaCd": signgu_cd[:2], "signguCd": signgu_cd},
        page_size=settings.crowd_page_size,
        max_pages=10,
        ttl=settings.upstream_cache_ttl_crowd,
        session_id=session_id,
    )

    by_name: dict[str, list[dict]] = {}
    for r in rows:
        name = r.get("tAtsNm")
        if not name:
            continue
        try:
            rate = round(float(r.get("cnctrRate")), 1)
        except (TypeError, ValueError):
            continue
        ymd = r.get("baseYmd") or ""
        if len(ymd) != 8:
            continue
        d = datetime.strptime(ymd, "%Y%m%d").date()
        by_name.setdefault(name, []).append(
            {
                "date": fmt(ymd),
                "weekday": _WEEKDAY[d.weekday()],
                "rate": rate,
                "level": grade(rate),
            }
        )

    for series in by_name.values():
        series.sort(key=lambda x: x["date"])
    return by_name


def slice_series(series: list[dict], date_from: str | None, days: int) -> list[dict]:
    start = date_from or clock.today_str()
    try:
        start_date = date.fromisoformat(start)
    except ValueError:
        start_date = clock.today()
        start = start_date.isoformat()
    end = (start_date + timedelta(days=days - 1)).isoformat()
    return [s for s in series if start <= s["date"] <= end]


def summarize(series: list[dict]) -> dict | None:
    if not series:
        return None
    peak = max(series, key=lambda x: x["rate"])
    low = min(series, key=lambda x: x["rate"])
    avg = round(sum(s["rate"] for s in series) / len(series), 1)
    return {
        "peak_date": peak["date"],
        "peak_rate": peak["rate"],
        "min_date": low["date"],
        "min_rate": low["rate"],
        "avg": avg,
    }


def day_rate(series: list[dict], on: str | None = None) -> dict | None:
    target = on or clock.today_str()
    for s in series:
        if s["date"] == target:
            return s
    return None


def aggregate(by_name: dict[str, list[dict]], on: str | None = None) -> dict:
    target = on or clock.today_str()
    summary = {k: 0 for k in LEVEL_KEY.values()}
    buckets: dict[str, list[dict]] = {k: [] for k in LEVEL_KEY.values()}

    for name, series in by_name.items():
        hit = next((s for s in series if s["date"] == target), None)
        if hit is None:
            continue
        key = LEVEL_KEY[hit["level"]]
        summary[key] += 1
        buckets[key].append({"name": name, "rate": hit["rate"]})

    for lvl in buckets:
        buckets[lvl].sort(key=lambda x: x["rate"])
        buckets[lvl] = buckets[lvl][:15]

    return {"date": target, "summary": summary, "samples": buckets}
