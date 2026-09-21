from __future__ import annotations

import re


def crowd_coverage(cards: list[dict]) -> dict | None:
    for c in cards:
        if c.get("type") != "crowd":
            continue
        cov = (c.get("payload") or {}).get("coverage")
        if isinstance(cov, dict):
            return cov
    return None


def near(a: int, b: int, text: str) -> bool:
    pa, pb = rf"(?<!\d){a}(?!\d)", rf"(?<!\d){b}(?!\d)"
    return bool(re.search(rf"{pa}.{{0,60}}?{pb}|{pb}.{{0,60}}?{pa}", text, re.DOTALL))


def coverage_stated(answer: str, cov: dict | None) -> bool:
    if not isinstance(cov, dict):
        return False
    total = cov.get("tourapi_total")
    with_data = cov.get("with_crowd_data")
    if not isinstance(total, int) or total <= 0 or not isinstance(with_data, int):
        return False
    return near(total, with_data, answer)
