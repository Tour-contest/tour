from __future__ import annotations


def josa(word: str, pair: str) -> str:
    if not word:
        return word
    last = word[-1]
    batchim = "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 != 0
    return word + (pair[0] if batchim else pair[1])


def pick(cards: list[dict], *types: str) -> dict | None:
    for c in cards:
        if c.get("type") in types:
            return c.get("payload") or {}
    return None

_ASKED_FOR = {
    "캠핑": ("캠핑", "야영", "글램핑", "카라반", "오토캠"),
    "음식": ("맛집", "음식점", "식당", "먹을"),
    "한식": ("한식", "밥집"),
    "숙박": ("숙소", "숙박", "호텔", "펜션", "민박"),
    "쇼핑": ("쇼핑", "아울렛"),
}


def unmet_category(cards: list[dict], message: str | None) -> str | None:
    if not message:
        return None
    got = (pick(cards, "attraction_list") or {}).get("category") or ""
    for name, words in _ASKED_FOR.items():
        if got != name and any(w in message for w in words):
            return name
    return None


def crowd_of(cards: list[dict]) -> tuple[dict | None, dict | None]:
    one = area = None
    for c in cards:
        if c.get("type") != "crowd":
            continue
        p = c.get("payload") or {}
        if p.get("items"):
            hit = next((i for i in p["items"] if i.get("series")), None)
            if hit and one is None:
                one = {**hit, "signgu_nm": p.get("signgu_nm")}
        elif p.get("series") is not None:
            if one is None:
                one = p
        elif p.get("summary") and area is None:
            area = p
    return one, area


def from_cards(cards: list[dict], message: str | None = None) -> str:
    parts: list[str] = []

    attraction = pick(cards, "attraction", "attraction_list", "detail")
    if attraction and attraction.get("items"):
        attraction = attraction["items"][0]

    one, area = crowd_of(cards)
    name = (attraction or {}).get("title") or (one or {}).get("name") or (one or {}).get("matched_name") or ""

    uncovered = next(
        (c.get("payload") or {} for c in cards
         if c.get("type") == "crowd" and (c.get("payload") or {}).get("has_crowd_data") is False),
        None,
    )
    if uncovered:
        parts.append(
            f"{josa(uncovered.get('signgu_nm') or '이 지역', '은는')} 아직 관광지 혼잡도가 "
            "제공되지 않는 지역이에요."
        )

    if one and one.get("series"):
        s = one.get("summary") or {}
        first = one["series"][0] or {}
        if first.get("date") and first.get("rate") and first.get("level"):
            parts.append(
                f"{josa(name or '이곳', '은는')} "
                f"{first['date']} 기준 {first['rate']}로 {first['level']}입니다."
            )
        if s and s.get("peak_date") != s.get("min_date"):
            parts.append(
                f"이 기간에는 {s['peak_date']}이 {s['peak_rate']}로 가장 붐비고, "
                f"{s['min_date']}이 {s['min_rate']}로 가장 한산합니다."
            )
        if one.get("match_method") and one["match_method"] != "exact":
            parts.append(f"'{one.get('name') or one.get('matched_name')}' 기준으로 찾아봤습니다.")
    elif one and one.get("has_data") is False:
        parts.append(one.get("message") or "이 관광지의 집중률 데이터가 아직 없어요.")

    if area:
        s = area["summary"]
        cov = area.get("coverage") or {}
        parts.append(
            f"{josa(area.get('signgu_nm', '이 지역'), '은는')} {area.get('date')} 기준 "
            f"혼잡 {s.get('crowded', 0)}곳, 보통 {s.get('normal', 0)}곳, 한적 {s.get('quiet', 0)}곳입니다."
        )
        if cov.get("tourapi_total"):
            parts.append(
                f"관광정보에 실린 {cov['tourapi_total']}곳 중 집중률이 나오는 "
                f"{cov['with_crowd_data']}곳을 본 결과입니다."
            )
        quiet = (area.get("samples") or {}).get("quiet") or []
        if quiet:
            parts.append("한적한 곳으로는 " + ", ".join(q["name"] for q in quiet[:3]) + " 같은 데가 있습니다.")

    alt = pick(cards, "alternatives")
    if alt and alt.get("items"):
        top = alt["items"][0] or {}
        if top.get("name") and top.get("rate") and top.get("level"):
            base_nm = (alt.get("base") or {}).get("name")
            if name:
                head = "대신 "
            elif base_nm:
                head = f"{base_nm} 대신 "
            else:
                head = "그중 "
            line = (f"{head}{josa(top['name'], '이가')} 같은 날 "
                    f"{top['rate']}로 {top['level']}합니다")
            d = (top.get("reason") or {}).get("distance_km")
            if d and (name or base_nm):
                line += f". 기준 관광지에서 약 {d}km 거리입니다"
            parts.append(line + ".")
        if alt.get("candidate_source") in ("area", "related+area"):
            parts.append("함께 많이 가는 곳들도 붐비는 편이라 같은 지역 전체에서 골랐습니다.")
        if alt.get("relaxed"):
            parts.append("여기보다 한적한 곳을 찾지 못해 혼잡도 낮은 순으로 보여드립니다.")
        if alt.get("sort_basis") == "popularity":
            parts.append("혼잡도 데이터가 없어 인기순으로 보여드립니다.")

    interest = pick(cards, "interest")
    if interest and interest.get("items"):
        it = interest["items"][0]
        if it.get("trend") == "rising":
            parts.append("최근 검색량이 오르는 중이라 예상보다 붐빌 수 있습니다.")
        elif it.get("trend") == "falling":
            parts.append("최근 검색량은 줄고 있습니다.")

    visitors = pick(cards, "visitors")
    if visitors and visitors.get("items"):
        last = visitors["items"][-1] or {}
        if last.get("date") and last.get("total") is not None:
            parts.append(
                f"{visitors.get('signgu_nm', '이 지역')}의 방문자 수는 "
                f"{last['date']} 기준 {last['total']:,}명입니다. 두 달쯤 지연된 값입니다."
            )

    if not parts:
        lst = pick(cards, "attraction_list")
        items = (lst or {}).get("items") or []
        if items:
            names = []
            for i in items[:5]:
                nm = i.get("title") or i.get("name") or ""
                extra = i.get("period") or i.get("note")
                if extra:
                    nm += f" ({extra})"
                c = i.get("crowd")
                if c:
                    nm += f" ({c['rate']} {c['level']})"
                names.append(nm)
            head = ("지금 하고 있거나 예정된 행사예요: "
                    if any(i.get("period") for i in items[:5])
                    else "이런 곳들이 있어요: ")
            parts.append(head + ", ".join(names) + ".")
            cov = (lst or {}).get("crowd_coverage")
            if cov and cov.get("with_crowd") and cov["with_crowd"] < cov.get("listed", 0):
                parts.append("숫자가 붙은 곳만 혼잡도가 집계되고, 나머지는 집계되지 않습니다.")
            elif cov and not cov.get("with_crowd"):
                parts.append("이 목록의 혼잡도는 집계되지 않습니다.")

    if not parts:
        return "조회 결과가 없어요. 지역명이나 관광지명을 다시 알려주세요."

    if uncovered and not (one or area):
        return " ".join(parts)

    if one or area or (alt and alt.get("items")):
        parts.append("집중률은 예측값이라 실제와 다를 수 있습니다.")

    unmet = unmet_category(cards, message)
    if unmet:
        parts.insert(0, f"'{unmet}' 조건에 맞는 목록은 확인하지 못했어요. "
                        f"아래는 그 지역 관광지 기준입니다.")
    return " ".join(parts)
