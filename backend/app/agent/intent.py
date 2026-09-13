from __future__ import annotations

import re
from datetime import date, timedelta

ALT_WORDS = ["한적", "대안", "추천", "덜 붐", "안 붐", "조용", "다른 곳", "다른데", "피해"]
OVERVIEW_WORDS = ["어때", "현황", "요즘", "전체", "상황"]

_SIDO_HINT = re.compile(
    r"(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)"
)
_TAIL = re.compile(r"(에서|으로|로|에|은|는|이|가|을|를|의|도|만|랑|과|와)$")


def drop_tail(tok: str) -> str:
    while True:
        m = _TAIL.search(tok)
        if not m or m.start() < 2:
            return tok
        tok = tok[: m.start()]


def parse_intent(text: str) -> dict:
    t = (text or "").strip()
    tokens = [drop_tail(x) for x in re.split(r"[\s,?!.]+", t) if x]
    tokens = [x for x in tokens if x]

    want_alt = any(w in t for w in ALT_WORDS)
    want_overview = any(w in t for w in OVERVIEW_WORDS)

    on = None
    days = 7
    today = date.today()
    if "오늘" in t:
        on = today.isoformat()
        days = 1
    elif "내일" in t:
        on = (today + timedelta(days=1)).isoformat()
        days = 1
    elif "주말" in t:
        ahead = (5 - today.weekday()) % 7
        on = (today + timedelta(days=ahead)).isoformat()
        days = 7
    elif "이번 주" in t or "이번주" in t:
        days = 7
    elif "다음 달" in t or "다음달" in t:
        days = 28

    stop = {
        "붐빌까", "붐벼", "붐비나", "붐비", "어때", "어떄", "추천해줘", "추천", "알려줘",
        "한적한", "한적", "곳", "데", "요즘", "이번", "주말", "오늘", "내일",
        "가는데", "가려는데", "현황", "전체", "상황", "좀", "어디", "어디가",
        "여행", "관광지", "사람", "많아", "적어", "다음", "지금",
    }
    words = [x for x in tokens if len(x) >= 2 and x not in stop and not x.isdigit()]

    pairs = [f"{words[i]} {words[i + 1]}" for i in range(len(words) - 1)]

    return {
        "tokens": words,
        "area_candidates": words + pairs,
        "date": on,
        "days": days,
        "want_alternatives": want_alt,
        "want_overview": want_overview,
    }
