from __future__ import annotations

import re

from rapidfuzz import fuzz, process

from app.repository import db
from app.services import datalab, tourapi

_SUFFIX = re.compile(r"(특별자치도|특별자치시|특별시|광역시|자치도|자치시|[시군구도])$")

# 2026년 광주광역시·전라남도가 전남광주통합특별시(12)로 합쳐지면서 사라진 코드.
# 관광정보·방문자수 API 는 새 코드(12xxx)로 넘어갔지만 연관 관광지 API 는 아직 옛 코드를 쓰고,
# 집중률 API 는 어느 쪽으로 다시 열릴지 정해지지 않아 두 코드를 같이 들고 있는다.
# 새 코드 -> 옛 코드. 2026-09-03 시점 코드표에서 그대로 가져왔다.
LEGACY_CODES = {
    "12210": "29110", "12240": "29140", "12270": "29155", "12300": "29170", "12330": "29200",
    "12110": "46110", "12130": "46130", "12150": "46150", "12170": "46170", "12190": "46230",
    "12710": "46710", "12720": "46720", "12730": "46730", "12740": "46770", "12750": "46780",
    "12760": "46790", "12770": "46800", "12780": "46810", "12790": "46820", "12800": "46830",
    "12810": "46840", "12820": "46860", "12830": "46870", "12840": "46880", "12850": "46890",
    "12860": "46900", "12870": "46910",
}

# 통합으로 시도가 없어진 옛 광역시는 하위 구를 묶는 상위 행을 따로 둔다. "광주" 라고만 물어도
# 5개 구를 한 번에 볼 수 있게 하기 위해서다. 옛 시도 코드 앞 두 자리 -> 묶음 정보.
GROUPS = {
    "29": {
        "crowd_cd": "29000", "area_cd": "12", "name": "광주",
        "aliases": ["광주", "광주광역시", "광주시", "전남 광주", "전남광주"],
    },
}


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


def group_of(crowd_cd: str) -> dict | None:
    legacy = LEGACY_CODES.get(crowd_cd)
    return GROUPS.get(legacy[:2]) if legacy else None


def grouped_name(crowd_cd: str, name: str) -> str:
    """묶음에 속한 구는 "광주 동구" 처럼 묶음 이름을 앞에 붙인다. 상위 행이 이 접두어로 하위를 찾는다."""
    g = group_of(crowd_cd)
    return f"{g['name']} {name}" if g else name


def grouped_aliases(sido: str, crowd_cd: str, name: str) -> list[str]:
    g = group_of(crowd_cd)
    full = grouped_name(crowd_cd, name)
    out = set(aliases(sido, full))
    if g:
        out.update({name, f"{g['name']}광역시 {name}", f"{g['name']}시 {name}"})
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
            sido_nm = crowd_sido.get(code[:2], hit["sido_nm"])
            rows.append(
                {
                    "crowd_cd": code,
                    "tour_cd": code,
                    "area_cd": code[:2],
                    "sido_nm": sido_nm,
                    "signgu_nm": grouped_name(code, name),
                    "aliases": grouped_aliases(sido_nm, code, name),
                    "legacy_cd": LEGACY_CODES.get(code),
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
                "signgu_nm": grouped_name(code, name),
                "aliases": grouped_aliases(sido_nm, code, name),
                "legacy_cd": LEGACY_CODES.get(code),
            }
        )

    await db.upsert_areas(rows)
    gone = await db.delete_areas_of(await stale_area_cds(tour))

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
        "removed": gone,
        "code_differs": len(leftovers),
        "tour_unmatched": unmatched,
    }


def sido_codes(tour: list[dict]) -> set[str]:
    return {t["tour_cd"][:2] for t in tour}


async def stale_area_cds(tour: list[dict]) -> set[str]:
    """관광정보 코드표에서 사라진 시도. 그 시도의 행은 더 이상 어떤 API 로도 조회가 안 된다."""
    live = sido_codes(tour)
    if not live:
        return set()
    return {a["area_cd"] for a in await db.all_areas() if a["area_cd"] not in live}


_stale_checked = False


async def is_stale() -> bool:
    """관광정보 코드표에 있는 시도가 DB 에 없으면 코드표를 다시 받아야 한다.

    프로세스당 한 번만 본다. 관광정보에는 있는데 방문자수 쪽에 없는 시도가 생기면 받아도 채워지지
    않아서, 매번 보면 대화마다 코드표를 다시 받는 일이 생긴다.
    """
    global _stale_checked
    if _stale_checked:
        return False
    _stale_checked = True
    have = {a["area_cd"] for a in await db.all_areas()}
    live = {(s["code"] or "")[:2] for s in await tourapi.ldong_codes()}
    return bool(live - have)


# 통합특별시는 이름은 특별시지만 시군 27개를 거느린 도 성격이라 광역시 상위 행을 만들지 않는다.
_METRO = re.compile(r"(?<!통합)특별시$|광역시$")

_SIDO_ALIAS = {
    "전라도": ("전남광주통합특별시", "전북특별자치도"),
    "경상도": ("경상북도", "경상남도"),
    "충청도": ("충청북도", "충청남도"),
    "강원도": ("강원특별자치도",),
    "제주도": ("제주특별자치도",),
    "전북": ("전북특별자치도",),
    "전남": ("전남광주통합특별시",),
    "전라남도": ("전남광주통합특별시",),
    "광주": ("전남광주통합특별시",),
    "광주광역시": ("전남광주통합특별시",),
}


def is_do(sido: str) -> bool:
    return sido.endswith("도") or sido.endswith("통합특별시")


def is_metro_parent(a: dict) -> bool:
    return a["signgu_nm"] == a["sido_nm"] and bool(_METRO.search(a["sido_nm"]))


def is_group_parent(a: dict) -> bool:
    return any(g["crowd_cd"] == a["crowd_cd"] for g in GROUPS.values())


def is_group_child(a: dict) -> bool:
    return group_of(a["crowd_cd"]) is not None


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


async def ensure_group_parents() -> None:
    areas = await db.all_areas()
    have = {a["crowd_cd"] for a in areas}
    rows = []
    for g in GROUPS.values():
        if g["crowd_cd"] in have:
            continue
        kids = [a for a in areas if a["area_cd"] == g["area_cd"]
                and a["signgu_nm"].startswith(g["name"] + " ")]
        if not kids:
            continue
        rows.append(
            {
                "crowd_cd": g["crowd_cd"],
                "tour_cd": None,
                "area_cd": g["area_cd"],
                "sido_nm": kids[0]["sido_nm"],
                "signgu_nm": g["name"],
                "aliases": sorted(set(g["aliases"])),
            }
        )
    if rows:
        await db.upsert_areas(rows)


async def ensure_loaded() -> None:
    if await db.area_count() == 0 or await is_stale():
        await load_codes()
    await ensure_metro_parents()
    await ensure_group_parents()
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
        rows = [a for a in areas if a["sido_nm"] == sido_nm and not is_group_child(a)]
        return {"status": "ambiguous", "sido_nm": sido_nm, "candidates": cands(rows[:30])}

    hit = match(q, areas)
    if hit:
        return hit

    return {"status": "not_found", "hint": "어느 지역을 말씀하시는 건가요? (예: 경주, 제주시, 강릉)"}
