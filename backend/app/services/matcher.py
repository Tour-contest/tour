from __future__ import annotations

import asyncio
import re

from rapidfuzz import fuzz

from app.core.errors import QuotaExceeded
from app.repository import db
from app.services import tourapi

_BRACKET = re.compile(r"\[[^\]]*\]")
_PAREN = re.compile(r"\([^)]*\)")


def short_name(name: str, signgu_nm: str = "") -> str:
    return keyword_variants(name, signgu_nm)[-1] or name


def keyword_variants(name: str, signgu_nm: str = "") -> list[str]:
    out = [name]
    a = _BRACKET.sub("", name).strip()
    b = _PAREN.sub("", a).strip()
    c = re.sub(r",.*$", "", b).strip()
    d = c
    if signgu_nm:
        bare = re.sub(r"[시군구]$", "", signgu_nm)
        d = re.sub(rf"^{re.escape(bare)}시?\s+", "", c).strip()
    for x in (a, b, c, d):
        if x and x not in out:
            out.append(x)
    return out


def same_area(a: str | None, b: str | None) -> bool:
    if not a or not b:
        return False
    if a == b:
        return True
    if b.endswith("000") or a.endswith("000"):
        return a[:2] == b[:2]
    return a[:4] == b[:4] and a.endswith("0") != b.endswith("0")


async def match_one(name: str, tour_cd: str, signgu_nm: str) -> dict | None:
    searched = False
    for i, kw in enumerate(keyword_variants(name, signgu_nm)):
        try:
            found = await tourapi.search_keyword(kw, rows=20)
            searched = True
        except QuotaExceeded:
            return None
        except Exception:
            continue
        if not found:
            continue

        local = [f for f in found if same_area(f.get("tour_cd"), tour_cd)]

        exact = [f for f in local if f["title"] == name]
        if not exact and i == 0:
            exact = [f for f in found if f["title"] == name]
        if exact:
            return {
                "tats_nm": name,
                "content_id": exact[0]["content_id"],
                "matched_title": exact[0]["title"],
                "match_method": "exact" if i == 0 else "normalized",
                "confidence": 1.0,
                "image": exact[0].get("image") or "",
            }

        if not local:
            continue

        if len(local) == 1 and i > 0:
            hit = local[0]
            return {
                "tats_nm": name,
                "content_id": hit["content_id"],
                "matched_title": hit["title"],
                "match_method": "normalized",
                "confidence": 0.9,
                "image": hit.get("image") or "",
            }

        scored = [(f, fuzz.partial_ratio(kw, f["title"])) for f in local]
        best, score = max(scored, key=lambda x: x[1])
        if score >= 85:
            return {
                "tats_nm": name,
                "content_id": best["content_id"],
                "matched_title": best["title"],
                "match_method": "normalized" if i > 0 else "fuzzy",
                "confidence": round(score / 100, 2),
                "image": best.get("image") or "",
            }

    if not searched:
        return None
    return {
        "tats_nm": name,
        "content_id": None,
        "matched_title": None,
        "match_method": None,
        "confidence": 0.0,
    }


_build_locks: dict[str, asyncio.Lock] = {}


async def ensure(
    crowd_cd: str, tour_cd: str, signgu_nm: str, names: list[str], *, budget: int = 40
) -> dict[str, dict]:
    async with _build_locks.setdefault(crowd_cd, asyncio.Lock()):
        return await ensure_locked(crowd_cd, tour_cd, signgu_nm, names, budget)


async def ensure_locked(
    crowd_cd: str, tour_cd: str, signgu_nm: str, names: list[str], budget: int
) -> dict[str, dict]:
    known = await db.get_mapping(crowd_cd)
    missing = [n for n in names if n not in known]
    if not missing:
        return known

    targets = missing[:budget]
    sem = asyncio.Semaphore(4)

    async def run(n: str):
        async with sem:
            return await match_one(n, tour_cd, signgu_nm)

    results = await asyncio.gather(*[run(n) for n in targets], return_exceptions=True)
    rows = [r for r in results if isinstance(r, dict)]
    await db.put_mapping(crowd_cd, rows)

    for r in rows:
        known[r["tats_nm"]] = r
    return known


def by_content_id(mapping: dict[str, dict]) -> dict[str, str]:
    return {v["content_id"]: k for k, v in mapping.items() if v.get("content_id")}


def delisted(mapping: dict[str, dict], name: str) -> bool:
    m = mapping.get(name)
    return m is not None and not m.get("content_id")


def reverse_match(title: str, names: list[str]) -> str | None:
    t = re.sub(r"\s", "", title or "")
    if not t:
        return None
    norm = {n: re.sub(r"\s", "", n) for n in names}
    exact = [n for n, k in norm.items() if k == t]
    if len(exact) == 1:
        return exact[0]
    part = [n for n, k in norm.items() if len(k) >= 2 and (k in t or t in k)]
    return part[0] if len(part) == 1 else None
