from __future__ import annotations

import time
from datetime import timedelta

import httpx

from app.core import clock
from app.core.config import settings
from app.services import client as upstream

URL = "https://naverapihub.apigw.ntruss.com/search-trend/v1/search"


def slope_pct(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    n = len(values)
    xs = list(range(n))
    mx = sum(xs) / n
    my = sum(values) / n
    denom = sum((x - mx) ** 2 for x in xs)
    if denom == 0:
        return 0.0
    slope = sum((xs[i] - mx) * (values[i] - my) for i in range(n)) / denom
    base = values[0] if values[0] else 1.0
    return round(slope * (n - 1) / base * 100, 1)


def judge(pct: float) -> str:
    if pct >= 15:
        return "rising"
    if pct <= -15:
        return "falling"
    return "flat"


async def fetch(names: list[str], weeks: int | None = None) -> dict:
    if not settings.naver_search_client_id:
        return {"status": "no_data", "items": []}

    names = [n for n in dict.fromkeys(names) if n][:5]
    if not names:
        return {"status": "no_data", "items": []}

    w = max(1, min(int(weeks or settings.trend_weeks), 52))
    end = clock.today() - timedelta(days=1)
    start = end - timedelta(weeks=w)

    body = {
        "startDate": start.isoformat(),
        "endDate": end.isoformat(),
        "timeUnit": "week",
        "keywordGroups": [{"groupName": n, "keywords": [n]} for n in names],
    }
    headers = {
        "X-NCP-APIGW-API-KEY-ID": settings.naver_search_client_id,
        "X-NCP-APIGW-API-KEY": settings.naver_search_client_secret,
        "Content-Type": "application/json",
    }

    started = time.monotonic()
    try:
        r = await upstream.get_client().post(URL, headers=headers, json=body)
        elapsed = int((time.monotonic() - started) * 1000)
    except httpx.HTTPError:
        return {"status": "upstream_error", "items": []}

    upstream.record_row(
        {
            "called_at": clock.now().isoformat(timespec="seconds"),
            "provider": "naver",
            "operation": "search-trend",
            "params": {"names": names, "weeks": w},
            "status_code": r.status_code,
            "result_code": "ok" if r.status_code == 200 else "error",
            "latency_ms": elapsed,
            "cache_hit": False,
            "session_id": None,
        }
    )

    if r.status_code != 200:
        return {"status": "upstream_error", "items": []}

    out = []
    for res in r.json().get("results", []):
        pts = res.get("data") or []
        vals = [float(p.get("ratio", 0)) for p in pts][-4:]
        pct = slope_pct(vals)
        out.append(
            {
                "name": res.get("title"),
                "trend": judge(pct),
                "change_pct": pct,
                "weeks": len(pts),
            }
        )
    return {"status": "ok", "items": out}
