from __future__ import annotations

import re

from rapidfuzz import fuzz, process

from app.repository import db
from app.services import datalab, tourapi

_SUFFIX = re.compile(r"(특별자치도|특별자치시|특별시|광역시|자치도|자치시|[시군구도])$")


def sido_short(sido: str) -> str:
    bare = _SUFFIX.sub("", sido)
    if len(bare) == 3:
        return bare[0] + bare[2]
    return bare[:2]


def aliases(sido: str, signgu: str) -> list[str]:
    out = {signgu}
    bare = _SUFFIX.sub("", signgu)
    if bare:
        out.add(bare)
    short = sido_short(sido)
    if short and short != bare:
        out.add(f"{short} {signgu}")
        if bare:
            out.add(f"{short} {bare}")
            out.add(f"{short}{bare}")
    return sorted(out)


async def tour_codes() -> list[dict]:
    out: list[dict] = []
    for sido in await tourapi.ldong_codes():
        code = sido["code"]
        if len(code) >= 5:
            out.append({"tour_cd": code[:5], "sido_nm": sido["name"], "signgu_nm": sido["name"]})
            continue
        for s in await tourapi.ldong_codes(code):
            sub = s["code"] or ""
            tour_cd = sub if len(sub) == 5 else f"{code}{sub}"
            if len(tour_cd) == 5:
                out.append({"tour_cd": tour_cd, "sido_nm": sido["name"], "signgu_nm": s["name"]})
    return out


async def load_codes() -> dict:
    tour = await tour_codes()
    crowd_sido = {s["code"]: s["name"] for s in await datalab.sido_list()}
    crowd = await datalab.signgu_list()

    tour_by_code = {t["tour_cd"]: t for t in tour}
    used: set[str] = set()
    rows: list[dict] = []
    leftovers: list[dict] = []

    for c in crowd:
        code, name = c["code"], c["name"]
        hit = tour_by_code.get(code)
        if hit and hit["signgu_nm"] == name:
            used.add(code)
            rows.append(
                {
                    "crowd_cd": code,
                    "tour_cd": code,
                    "area_cd": code[:2],
                    "sido_nm": crowd_sido.get(code[:2], hit["sido_nm"]),
                    "signgu_nm": name,
                    "aliases": aliases(crowd_sido.get(code[:2], hit["sido_nm"]), name),
                }
            )
        else:
            leftovers.append(c)

    remain = [t for t in tour if t["tour_cd"] not in used]
    taken: set[str] = set()
    for c in leftovers:
        code, name = c["code"], c["name"]
        sido_nm = crowd_sido.get(code[:2], "")
        want = sido_short(sido_nm)
        hit = next(
            (
                t
                for t in remain
                if t["signgu_nm"] == name
                and t["tour_cd"] not in taken
                and (not want or want in t["sido_nm"])
            ),
            None,
        )
        if hit:
            taken.add(hit["tour_cd"])
        rows.append(
            {
                "crowd_cd": code,
                "tour_cd": hit["tour_cd"] if hit else None,
                "area_cd": code[:2],
                "sido_nm": sido_nm,
                "signgu_nm": name,
                "aliases": aliases(sido_nm, name),
            }
        )

    await db.upsert_areas(rows)

    try:
        cats = await tourapi.lcls_codes()
        await db.put_categories([{"code": c["code"], "name": c["name"], "level": 1} for c in cats])
    except Exception:
        cats = []

    unmatched = [r["signgu_nm"] for r in rows if not r["tour_cd"]]
    return {
        "categories": len(cats),
        "tour": len(tour),
        "crowd": len(crowd),
        "saved": len(rows),
        "code_differs": len(leftovers),
        "tour_unmatched": unmatched,
    }


_METRO = re.compile(r"(특별시|광역시)$")

_SIDO_ALIAS = {
    "전라도": ("전라남도", "전북특별자치도"),
    "경상도": ("경상북도", "경상남도"),
    "충청도": ("충청북도", "충청남도"),
    "강원도": ("강원특별자치도",),
    "제주도": ("제주특별자치도",),
    "전북": ("전북특별자치도",),
    "전남": ("전라남도",),
}


def is_do(sido: str) -> bool:
    return sido.endswith("도")


def is_metro_parent(a: dict) -> bool:
    return a["signgu_nm"] == a["sido_nm"] and bool(_METRO.search(a["sido_nm"]))


def metro_aliases(sido: str) -> list[str]:
    bare = _METRO.sub("", sido)
    return sorted({sido, bare, f"{bare}시"})


async def ensure_metro_parents() -> None:
    areas = await db.all_areas()
    have = {a["signgu_nm"] for a in areas}
    rows = []
    for sido in sorted({a["sido_nm"] for a in areas if _METRO.search(a["sido_nm"])}):
        if sido in have:
            continue
        kid = next(a for a in areas if a["sido_nm"] == sido)
        rows.append(
            {
                "crowd_cd": f"{kid['area_cd']}000",
                "tour_cd": None,
                "area_cd": kid["area_cd"],
                "sido_nm": sido,
                "signgu_nm": sido,
                "aliases": metro_aliases(sido),
            }
        )
    if rows:
        await db.upsert_areas(rows)


async def ensure_loaded() -> None:
    if await db.area_count() == 0:
        await load_codes()
    await ensure_metro_parents()
    await db.promote_parent_crowd_flags()


def cands(rows: list[dict]) -> list[dict]:
    return [{"signgu_cd": a["signgu_cd"], "label": a["label"]} for a in rows]


def sido_of(token: str, areas: list[dict]) -> set[str]:
    names = {a["sido_nm"] for a in areas}
    if token in names:
        return {token}
    hit = {n for n in names if sido_short(n) == token}
    if hit:
        return hit
    return {n for n in _SIDO_ALIAS.get(token, ()) if n in names}


def match(q: str, pool: list[dict]) -> dict | None:
    exact = [a for a in pool if q in a["aliases"] or q == a["signgu_nm"] or q == a["label"]]
    if len(exact) == 1:
        return {"status": "ok", **exact[0]}
    if len(exact) > 1:
        return {"status": "ambiguous", "candidates": cands(exact)}

    choices = {a["signgu_cd"]: " ".join(a["aliases"] + [a["label"]]) for a in pool}
    best = process.extract(q, choices, scorer=fuzz.token_set_ratio, limit=5)
    hits = [b for b in best if b[1] >= 88]
    if not hits:
        return None
    rows = [next(x for x in pool if x["signgu_cd"] == code) for _, _, code in hits]
    if len(rows) == 1:
        return {"status": "ok", **rows[0]}
    return {"status": "ambiguous", "candidates": cands(rows)}


async def resolve(query: str) -> dict:
    await ensure_loaded()
    areas = await db.all_areas()
    q = (query or "").strip()
    if not q:
        return {"status": "not_found", "hint": "지역명을 입력해주세요"}

    head, _, tail = q.partition(" ")
    tail = tail.strip()
    if tail and (sidos := sido_of(head, areas)):
        hit = match(tail, [a for a in areas if a["sido_nm"] in sidos])
        wider = [a for a in areas if a["sido_nm"] in sidos or not is_do(a["sido_nm"])]
        return hit or match(tail, wider) or {
            "status": "not_found",
            "hint": f"{head}에는 그런 지역이 없어요. 어느 지역을 말씀하시는 건가요?",
        }

    exact = [a for a in areas if q in a["aliases"] or q == a["signgu_nm"] or q == a["label"]]
    if len(exact) == 1:
        return {"status": "ok", **exact[0]}
    if len(exact) > 1:
        return {"status": "ambiguous", "candidates": cands(exact)}

    sidos = sido_of(q, areas)
    if len(sidos) == 1:
        sido_nm = next(iter(sidos))
        rows = [a for a in areas if a["sido_nm"] == sido_nm]
        return {"status": "ambiguous", "sido_nm": sido_nm, "candidates": cands(rows[:30])}

    hit = match(q, areas)
    if hit:
        return hit

    return {"status": "not_found", "hint": "어느 지역을 말씀하시는 건가요? (예: 경주, 제주시, 강릉)"}
