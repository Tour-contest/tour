"""서비스 기준 시간대(REPORT_TZ)의 현재 시각·날짜.

서버 OS 시간대와 무관하게 한국 기준으로 '오늘'을 정해야 하는 곳은 전부 여기를 쓴다.
date.today() 를 직접 부르면 서버가 UTC 일 때 한국 시간 0시~9시 사이에 전날로 잡힌다.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo

from app.core.config import settings

try:
    TZ = ZoneInfo(settings.report_tz)
except Exception:
    TZ = datetime.now().astimezone().tzinfo or timezone.utc


def now() -> datetime:
    return datetime.now(TZ)


def today() -> date:
    return now().date()


def today_str() -> str:
    return today().isoformat()
