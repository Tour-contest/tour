"""사용자 문장의 상대 날짜 표현을 실제 날짜로 푼다.

"다음 주 화요일", "이번 주말", "모레", "10월 3일" 같은 표현을 모델이 스스로 계산하면
요일을 자주 틀린다. 서버가 먼저 풀어서 시스템 메시지로 넣어 주고, 모델은 그 값을 도구의
date 에 옮겨 적기만 하게 한다.
"""
from __future__ import annotations

import re
from datetime import date, timedelta

WEEKDAY = ["월", "화", "수", "목", "금", "토", "일"]
_WD = {w: i for i, w in enumerate(WEEKDAY)}
_WEEK_OFFSET = {"이번": 0, "다음": 1, "다다음": 2}

_WEEK_DAY = re.compile(r"(이번|다음|다다음)\s*주\s*(월|화|수|목|금|토|일)요일")
_WEEKEND = re.compile(r"(이번|다음|다다음)?\s*주말")
_RELATIVE = re.compile(r"(?<![가-힣])(오늘|내일|모레|글피)")
_MONTH_DAY = re.compile(r"(\d{1,2})\s*월\s*(\d{1,2})\s*일")
_DAYS_LATER = re.compile(r"(\d{1,2})\s*일\s*(뒤|후)")
_ISO = re.compile(r"(20\d{2})-(\d{2})-(\d{2})")

_RELATIVE_DAYS = {"오늘": 0, "내일": 1, "모레": 2, "글피": 3}


def monday_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


def coming_saturday(today: date) -> date:
    if today.weekday() == 6:
        return today
    return today + timedelta(days=(5 - today.weekday()) % 7)


def resolve(text: str, today: date) -> list[tuple[str, date]]:
    """문장에서 찾은 (표현, 날짜) 목록. 같은 날짜는 한 번만."""
    found: list[tuple[str, date]] = []
    taken: list[tuple[int, int]] = []

    def add(m: re.Match, d: date) -> None:
        span = m.span()
        if any(s <= span[0] < e or s < span[1] <= e for s, e in taken):
            return
        taken.append(span)
        found.append((m.group(0).strip(), d))

    for m in _ISO.finditer(text):
        try:
            add(m, date(int(m.group(1)), int(m.group(2)), int(m.group(3))))
        except ValueError:
            pass

    for m in _WEEK_DAY.finditer(text):
        base = monday_of(today) + timedelta(weeks=_WEEK_OFFSET[m.group(1)])
        add(m, base + timedelta(days=_WD[m.group(2)]))

    for m in _WEEKEND.finditer(text):
        which = m.group(1)
        if which is None:
            add(m, coming_saturday(today))
        else:
            base = monday_of(today) + timedelta(weeks=_WEEK_OFFSET[which])
            sat = base + timedelta(days=5)
            add(m, today if which == "이번" and today > sat else sat)

    for m in _MONTH_DAY.finditer(text):
        month, day = int(m.group(1)), int(m.group(2))
        try:
            d = date(today.year, month, day)
        except ValueError:
            continue
        if d < today - timedelta(days=30):
            d = date(today.year + 1, month, day)
        add(m, d)

    for m in _DAYS_LATER.finditer(text):
        add(m, today + timedelta(days=int(m.group(1))))

    for m in _RELATIVE.finditer(text):
        add(m, today + timedelta(days=_RELATIVE_DAYS[m.group(1)]))

    seen: set[date] = set()
    out = []
    for expr, d in found:
        if d in seen:
            continue
        seen.add(d)
        out.append((expr, d))
    return out


def note(text: str, today: date) -> str:
    """모델에게 줄 한 줄. 표현이 없으면 빈 문자열."""
    hits = resolve(text, today)
    if not hits:
        return ""
    parts = ", ".join(f"'{expr}' = {d.isoformat()}({WEEKDAY[d.weekday()]})" for expr, d in hits)
    return f"사용자가 말한 날짜: {parts}. 도구의 date, date_from 에는 이 값을 그대로 넣는다."
