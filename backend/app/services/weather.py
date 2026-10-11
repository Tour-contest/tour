"""기상청 단기예보·초단기실황·중기예보로 관광지 날짜별 날씨를 만든다.

날짜와 오늘의 차이로 어느 예보를 쓸지 서버가 고른다. 0~3일은 단기예보(시간대별),
4~10일은 중기예보(오전·오후), 그 뒤는 예보가 없다. 오늘이면 실황을 같이 붙인다.
단기예보는 위경도가 아니라 기상청 격자(nx, ny)를 쓰고, 중기예보는 예보구역 코드를 쓴다.
"""
from __future__ import annotations

import asyncio
import math
from collections import Counter
from datetime import date, datetime, timedelta

from app.core import clock
from app.core.config import settings
from app.services import client

VILAGE = "VilageFcstInfoService_2.0/getVilageFcst"
NCST = "VilageFcstInfoService_2.0/getUltraSrtNcst"
MID_LAND = "MidFcstInfoService/getMidLandFcst"
MID_TA = "MidFcstInfoService/getMidTa"

SOURCE = "출처: 기상청"
SHORT_DAYS = 3
MID_DAYS = 10

WEEKDAY = ["월", "화", "수", "목", "금", "토", "일"]

SKY = {"1": "맑음", "3": "구름많음", "4": "흐림"}
PTY = {
    "0": "", "1": "비", "2": "비/눈", "3": "눈", "4": "소나기",
    "5": "빗방울", "6": "빗방울/눈날림", "7": "눈날림",
}

# 중기육상예보 구역. 강원은 영동·영서가 갈린다.
LAND_REG = {
    "서울": "11B00000", "인천": "11B00000", "경기": "11B00000",
    "대전": "11C20000", "세종": "11C20000", "충남": "11C20000", "충북": "11C10000",
    "광주": "11F20000", "전남": "11F20000", "전북": "11F10000",
    "대구": "11H10000", "경북": "11H10000",
    "부산": "11H20000", "울산": "11H20000", "경남": "11H20000",
    "제주": "11G00000",
}
YEONGDONG = {"강릉시", "속초시", "동해시", "삼척시", "태백시", "고성군", "양양군"}

# 중기기온 지점. 기상청 중기예보 화면의 코드와 지점 대략 좌표. 가장 가까운 지점을 쓴다.
TA_POINTS = [
    ("11B10101", "서울", 37.566, 126.978), ("11B20201", "인천", 37.456, 126.705),
    ("11B20601", "수원", 37.263, 127.029), ("11B20305", "파주", 37.760, 126.780),
    ("11B20701", "이천", 37.272, 127.435), ("11B20606", "평택", 36.992, 127.113),
    ("11D10301", "춘천", 37.881, 127.730), ("11D10401", "원주", 37.342, 127.920),
    ("11D20501", "강릉", 37.752, 128.876), ("11C20401", "대전", 36.351, 127.385),
    ("11C20404", "세종", 36.480, 127.289), ("11C20104", "홍성", 36.601, 126.661),
    ("11C10301", "청주", 36.642, 127.489), ("11C10101", "충주", 36.991, 127.926),
    ("11C10402", "영동", 36.175, 127.783), ("11F20501", "광주", 35.160, 126.851),
    ("21F20801", "목포", 34.812, 126.392), ("11F20401", "여수", 34.760, 127.662),
    ("11F20603", "순천", 34.950, 127.487), ("11F20402", "광양", 34.940, 127.696),
    ("11F20503", "나주", 35.016, 126.711), ("11F10201", "전주", 35.824, 127.148),
    ("21F10501", "군산", 35.968, 126.737), ("11F10203", "정읍", 35.570, 126.856),
    ("11F10401", "남원", 35.416, 127.390), ("21F10601", "고창", 35.436, 126.702),
    ("11F10302", "무주", 36.007, 127.661), ("11H20201", "부산", 35.180, 129.075),
    ("11H20101", "울산", 35.539, 129.311), ("11H20301", "창원", 35.228, 128.681),
    ("11H20701", "진주", 35.180, 128.108), ("11H20502", "거창", 35.687, 127.910),
    ("11H20401", "통영", 34.854, 128.433), ("11H10701", "대구", 35.871, 128.602),
    ("11H10501", "안동", 36.568, 128.730), ("11H10201", "포항", 36.019, 129.343),
    ("11H10202", "경주", 35.856, 129.225), ("11H10101", "울진", 36.993, 129.400),
    ("11E00101", "울릉도", 37.484, 130.906), ("11G00201", "제주", 33.500, 126.531),
    ("11G00401", "서귀포", 33.254, 126.560),
]


def grid(lat: float, lon: float) -> tuple[int, int]:
    """위경도를 기상청 단기예보 격자(nx, ny)로. 람베르트 정각원추도법, 격자 5km."""
    re = 6371.00877 / 5.0
    slat1, slat2 = math.radians(30.0), math.radians(60.0)
    olon, olat = math.radians(126.0), math.radians(38.0)
    xo, yo = 43, 136

    sn = math.tan(math.pi * 0.25 + slat2 * 0.5) / math.tan(math.pi * 0.25 + slat1 * 0.5)
    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(sn)
    sf = math.tan(math.pi * 0.25 + slat1 * 0.5) ** sn * math.cos(slat1) / sn
    ro = re * sf / math.tan(math.pi * 0.25 + olat * 0.5) ** sn

    ra = re * sf / math.tan(math.pi * 0.25 + math.radians(lat) * 0.5) ** sn
    theta = math.radians(lon) - olon
    if theta > math.pi:
        theta -= 2 * math.pi
    if theta < -math.pi:
        theta += 2 * math.pi
    theta *= sn
    nx = int(math.floor(ra * math.sin(theta) + xo + 0.5))
    ny = int(math.floor(ro - ra * math.cos(theta) + yo + 0.5))
    return nx, ny


def land_region(sido_short: str, signgu_nm: str) -> str | None:
    if sido_short == "강원":
        return "11D20000" if signgu_nm in YEONGDONG else "11D10000"
    return LAND_REG.get(sido_short)


def ta_region(lat: float, lon: float) -> str:
    return min(TA_POINTS, key=lambda p: (p[2] - lat) ** 2 + ((p[3] - lon) * 0.8) ** 2)[0]


def vilage_base(now: datetime) -> tuple[str, str]:
    """단기예보 최신 발표 회차. 02·05·…·23시 발표이고 10분 뒤부터 받을 수 있다."""
    for h in (23, 20, 17, 14, 11, 8, 5, 2):
        issued = now.replace(hour=h, minute=10, second=0, microsecond=0)
        if issued <= now:
            return now.strftime("%Y%m%d"), f"{h:02d}00"
    prev = now - timedelta(days=1)
    return prev.strftime("%Y%m%d"), "2300"


def ncst_base(now: datetime) -> tuple[str, str]:
    """초단기실황은 매시 정각 값이 10분 뒤에 나온다. 여유를 두고 40분 전 정각을 본다."""
    t = now - timedelta(minutes=40)
    return t.strftime("%Y%m%d"), f"{t.hour:02d}00"


def mid_tmfc(now: datetime) -> tuple[date, str]:
    """중기예보 최신 회차. 06시·18시 발표이고 발표 전이면 직전 회차다."""
    if now >= now.replace(hour=18, minute=10, second=0, microsecond=0):
        return now.date(), now.strftime("%Y%m%d") + "1800"
    if now >= now.replace(hour=6, minute=10, second=0, microsecond=0):
        return now.date(), now.strftime("%Y%m%d") + "0600"
    prev = now.date() - timedelta(days=1)
    return prev, prev.strftime("%Y%m%d") + "1800"


def mid_issues(now: datetime) -> list[tuple[date, str]]:
    """최신 회차와 그 직전 회차.

    06시 발표분은 4~10일 뒤를, 18시 발표분은 5~10일 뒤만 준다. 그래서 저녁에 4일 뒤를 물으면
    직전 회차(06시)를 봐야 한다. 발표 직후 최신 회차가 아직 비어 있을 때도 직전 회차로 넘어간다.
    """
    latest = mid_tmfc(now)
    return [latest, mid_tmfc(now - timedelta(hours=12))]


def num(v) -> float | None:
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return None if f <= -900 else f


def hour_label(hhmm: str) -> str:
    return f"{int(hhmm[:2])}시"


def daily_from_vilage(rows: list[dict], day: date) -> dict | None:
    """단기예보 항목들에서 하루치 요약. 해당 날짜 항목이 없으면 None."""
    ymd = day.strftime("%Y%m%d")
    by_time: dict[str, dict[str, str]] = {}
    for r in rows:
        if r.get("fcstDate") != ymd:
            continue
        slot = by_time.setdefault(r.get("fcstTime", ""), {})
        slot[r.get("category", "")] = r.get("fcstValue", "")
    if not by_time:
        return None

    times = sorted(by_time)
    temps = [t for t in (num(by_time[k].get("TMP")) for k in times) if t is not None]
    tmn = next((num(v["TMN"]) for v in by_time.values() if v.get("TMN")), None)
    tmx = next((num(v["TMX"]) for v in by_time.values() if v.get("TMX")), None)
    pops = [p for p in (num(by_time[k].get("POP")) for k in times) if p is not None]

    daytime = [k for k in times if "0900" <= k <= "1800"] or times
    skies = Counter(SKY.get(by_time[k].get("SKY", ""), "") for k in daytime)
    skies.pop("", None)
    sky = skies.most_common(1)[0][0] if skies else ""

    precip_hours = [k for k in times if PTY.get(by_time[k].get("PTY", "0"), "")]
    precip = Counter(PTY[by_time[k]["PTY"]] for k in precip_hours)

    hourly = [
        {
            "time": hour_label(k),
            "temp": num(by_time[k].get("TMP")),
            "sky": SKY.get(by_time[k].get("SKY", ""), ""),
            "pop": num(by_time[k].get("POP")),
            "precip": PTY.get(by_time[k].get("PTY", "0"), ""),
        }
        for k in times
        if k in ("0600", "0900", "1200", "1500", "1800", "2100")
    ]

    span = ""
    if precip_hours:
        span = f"{hour_label(precip_hours[0])}~{hour_label(precip_hours[-1])}"

    return {
        "tmin": tmn if tmn is not None else (min(temps) if temps else None),
        "tmax": tmx if tmx is not None else (max(temps) if temps else None),
        "sky": sky,
        "pop_max": max(pops) if pops else None,
        "precip": precip.most_common(1)[0][0] if precip else "",
        "precip_hours": span,
        "hourly": hourly,
        "from_hour": hour_label(times[0]),
        "hours_covered": len(times),
    }


def now_from_ncst(rows: list[dict]) -> dict | None:
    vals = {r.get("category"): r.get("obsrValue") for r in rows}
    if not vals:
        return None
    return {
        "temp": num(vals.get("T1H")),
        "precip": PTY.get(str(vals.get("PTY", "0")), ""),
        "rain_1h_mm": num(vals.get("RN1")),
        "humidity": num(vals.get("REH")),
        "wind_ms": num(vals.get("WSD")),
    }


def mid_days(land: dict, ta: dict, issued: date) -> dict[date, dict]:
    """중기예보 응답을 날짜별로. 발표일 기준 4~10일 뒤."""
    out: dict[date, dict] = {}
    for n in range(4, MID_DAYS + 1):
        d = issued + timedelta(days=n)
        am_sky = land.get(f"wf{n}Am") or land.get(f"wf{n}") or ""
        pm_sky = land.get(f"wf{n}Pm") or land.get(f"wf{n}") or ""
        am_pop = num(land.get(f"rnSt{n}Am", land.get(f"rnSt{n}")))
        pm_pop = num(land.get(f"rnSt{n}Pm", land.get(f"rnSt{n}")))
        if not (am_sky or pm_sky):
            continue
        out[d] = {
            "am": {"sky": am_sky, "pop": am_pop},
            "pm": {"sky": pm_sky, "pop": pm_pop},
            "tmin": num(ta.get(f"taMin{n}")),
            "tmax": num(ta.get(f"taMax{n}")),
        }
    return out


async def fetch_vilage(nx: int, ny: int, session_id=None) -> list[dict]:
    base_date, base_time = vilage_base(clock.now())
    rows, _ = await client.call(
        VILAGE,
        {"dataType": "JSON", "numOfRows": 1500, "pageNo": 1,
         "base_date": base_date, "base_time": base_time, "nx": nx, "ny": ny},
        ttl=settings.weather_cache_ttl, session_id=session_id,
        common=False,
    )
    return rows


async def fetch_ncst(nx: int, ny: int, session_id=None) -> list[dict]:
    base_date, base_time = ncst_base(clock.now())
    rows, _ = await client.call(
        NCST,
        {"dataType": "JSON", "numOfRows": 20, "pageNo": 1,
         "base_date": base_date, "base_time": base_time, "nx": nx, "ny": ny},
        ttl=settings.weather_cache_ttl, session_id=session_id,
        common=False,
    )
    return rows


async def fetch_mid(op: str, reg_id: str, tmfc: str, session_id=None) -> dict:
    rows, _ = await client.call(
        op,
        {"dataType": "JSON", "numOfRows": 10, "pageNo": 1, "regId": reg_id, "tmFc": tmfc},
        ttl=settings.weather_cache_ttl, session_id=session_id,
        common=False,
    )
    return rows[0] if rows else {}


async def forecast(
    lat: float, lon: float, day: date, sido_short: str, signgu_nm: str, session_id=None
) -> dict:
    today = clock.today()
    delta = (day - today).days
    out: dict = {
        "status": "ok",
        "date": day.isoformat(),
        "weekday": WEEKDAY[day.weekday()],
        "source": SOURCE,
    }

    if delta < 0:
        return {**out, "status": "no_data", "kind": "past",
                "message": "지난 날짜의 날씨는 조회할 수 없어요."}

    if delta > MID_DAYS:
        return {**out, "status": "no_data", "kind": "out_of_range",
                "message": f"기상청 예보는 {MID_DAYS}일 뒤까지만 나와요. "
                           f"{day.isoformat()} 날씨는 아직 조회할 수 없어요."}

    if delta <= SHORT_DAYS:
        nx, ny = grid(lat, lon)
        if delta == 0:
            vilage, ncst = await asyncio.gather(
                fetch_vilage(nx, ny, session_id), fetch_ncst(nx, ny, session_id),
                return_exceptions=True,
            )
            if isinstance(vilage, BaseException):
                raise vilage
            if not isinstance(ncst, BaseException):
                out["now"] = now_from_ncst(ncst)
        else:
            vilage = await fetch_vilage(nx, ny, session_id)
        daily = daily_from_vilage(vilage, day)
        # 발표 회차에 따라 3일 뒤는 하루치가 다 안 올 수 있다. 그때는 중기예보로 넘어간다.
        if daily and (delta < SHORT_DAYS or daily["hours_covered"] >= 12):
            return {**out, "kind": "short", "forecast": daily}

    land_reg = land_region(sido_short, signgu_nm)
    if not land_reg:
        return {**out, "status": "no_data", "kind": "mid",
                "message": "이 지역의 중기예보 구역을 찾지 못했어요."}
    hit = None
    for issued, tmfc in mid_issues(clock.now()):
        land, ta = await asyncio.gather(
            fetch_mid(MID_LAND, land_reg, tmfc, session_id),
            fetch_mid(MID_TA, ta_region(lat, lon), tmfc, session_id),
        )
        # 18시 발표분은 5일 뒤부터만 준다. 그 날짜가 없으면 4일 뒤까지 주는 06시 발표분을 본다.
        hit = mid_days(land, ta, issued).get(day) if land else None
        if hit:
            break
    if not hit:
        return {**out, "status": "no_data", "kind": "mid",
                "message": f"{day.isoformat()} 예보가 아직 발표되지 않았어요."}
    return {**out, "kind": "mid", "forecast": hit}
