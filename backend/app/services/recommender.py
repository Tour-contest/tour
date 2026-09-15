from __future__ import annotations

import asyncio
import math

from app.services import crowding, embedding, matcher, related, tourapi


def haversine(lat1, lon1, lat2, lon2) -> float | None:
    if None in (lat1, lon1, lat2, lon2):
        return None
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return round(2 * r * math.asin(math.sqrt(a)), 1)


async def alternatives(
    base: dict,
    crowd_cd: str,
    tour_cd: str,
    signgu_nm: str,
    by_name: dict[str, list[dict]],
    mapping: dict[str, dict],
    *,
    on: str | None = None,
    limit: int = 5,
    session_id: str | None = None,
) -> dict:
    base_name = base.get("matched_name") or base.get("title") or ""
    base_series = by_name.get(base_name, [])
    base_day = crowding.day_rate(base_series, on)
    base_rate = base_day["rate"] if base_day else None

    def to_rows(names: list[str]) -> list[dict]:
        out, seen = [], set()
        for c in names:
            hit = c if c in by_name else next((n for n in by_name if c in n or n in c), None)
            if not hit or hit == base_name or hit in seen:
                continue
            if matcher.delisted(mapping, hit):
                continue
            day = crowding.day_rate(by_name.get(hit, []), on)
            if not day:
                continue
            seen.add(hit)
            out.append(
                {
                    "name": hit,
                    "content_id": (mapping.get(hit) or {}).get("content_id"),
                    "rate": day["rate"],
                    "level": day["level"],
                    "date": day["date"],
                }
            )
        return out

    def quieter(rows: list[dict]) -> list[dict]:
        if base_rate is None:
            return rows
        return [r for r in rows if r["rate"] < base_rate]

    source = "related"
    rows: list[dict] = []
    try:
        kw = matcher.short_name(base.get("title") or base_name, signgu_nm)
        rel = await related.by_keyword(kw, crowd_cd, session_id=session_id)
        rows = quieter(to_rows([r["name"] for r in rel]))
    except Exception:
        rows = []

    relaxed = False
    if not rows or not any(r["level"] == "한적" for r in rows):
        extra = quieter(to_rows(list(by_name.keys())))
        if extra:
            known = {r["name"] for r in rows}
            merged = rows + [e for e in extra if e["name"] not in known]
            source = "area" if not rows else "related+area"
            rows = merged

    sim_map: dict[str, float] = {}
    if rows and base.get("content_id"):
        try:
            sims = await embedding.similar(
                base["content_id"], crowd_cd, limit=20, min_similarity=0.0
            )
            by_cid = {v.get("content_id"): k for k, v in mapping.items() if v.get("content_id")}
            for s in sims:
                name = by_cid.get(s["content_id"])
                if name:
                    sim_map[name] = s["similarity"]
        except Exception:
            sim_map = {}

    if not rows:
        relaxed = True
        rows = to_rows(list(by_name.keys()))

    if not rows:
        return {
            "status": "no_data",
            "base": {"name": base_name, "rate": base_rate},
            "items": [],
            "sort_basis": "none",
            "relaxed": False,
        }

    for r in rows:
        r["similarity"] = sim_map.get(r["name"])
    rows.sort(key=lambda r: (round(r["rate"] / 10), -(r.get("similarity") or 0), r["rate"]))
    picked = rows[:limit]

    async def detail_of(cid: str | None) -> dict | None:
        if not cid:
            return None
        try:
            return await tourapi.detail_common(cid, session_id=session_id)
        except Exception:
            return None

    # 상세 조회는 서로 독립이라 한꺼번에 던진다. 동시 건수는 상류 클라이언트가 제한한다.
    details = await asyncio.gather(*[detail_of(r["content_id"]) for r in picked])

    for r, d in zip(picked, details):
        reason = {
            "lower_by": None,
            "same_category": None,
            "distance_km": None,
            "similarity": r.pop("similarity", None),
        }
        if base_rate is not None:
            reason["lower_by"] = round(base_rate - r["rate"], 1)
        if r["content_id"]:
            if d:
                r["image"] = d.get("image") or ""
                r["addr1"] = d.get("addr1") or ""
                reason["same_category"] = bool(
                    base.get("lcls1") and d.get("lcls1") == base.get("lcls1")
                )
                reason["distance_km"] = haversine(
                    base.get("mapy"), base.get("mapx"), d.get("mapy"), d.get("mapx")
                )
        r["reason"] = reason

    return {
        "status": "ok",
        "base": {"name": base_name, "rate": base_rate, "level": base_day["level"] if base_day else None},
        "items": picked,
        "sort_basis": "crowding",
        "relaxed": relaxed,
        "candidate_source": source,
    }
