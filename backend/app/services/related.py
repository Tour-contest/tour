from __future__ import annotations

from app.core.config import settings
from app.repository import db
from app.services import client


def signgu(regn: str | None, sig: str | None) -> str | None:
    regn = (regn or "").strip()
    sig = (sig or "").strip()
    if len(sig) == 5:
        sig = sig[2:]
    if len(regn) == 2 and len(sig) == 3 and (regn + sig).isdigit():
        return regn + sig
    return None


async def api_code(signgu_cd: str) -> str:
    """연관 관광지 API 가 아는 코드. 통합 지역은 아직 옛 코드(29xxx·46xxx)로만 조회된다."""
    a = await db.get_area(signgu_cd)
    return (a or {}).get("legacy_cd") or signgu_cd


async def by_keyword(
    keyword: str, signgu_cd: str, *, rows: int = 30, session_id: str | None = None
) -> list[dict]:
    signgu_cd = await api_code(signgu_cd)
    items, _ = await client.call(
        "TarRlteTarService1/searchKeyword1",
        {
            "keyword": keyword,
            "baseYm": settings.tarrltetar_base_ym,
            "areaCd": signgu_cd[:2],
            "signguCd": signgu_cd,
            "numOfRows": rows,
            "pageNo": 1,
        },
        ttl=86400,
        session_id=session_id,
    )
    out = []
    for r in items:
        name = r.get("rlteTatsNm")
        if not name:
            continue
        out.append(
            {
                "name": name,
                "rank": int(r.get("rlteRank") or 999),
                "signgu_cd": signgu(r.get("rlteRegnCd"), r.get("rlteSignguCd")),
                "category": r.get("rlteCtgrySclsNm") or "",
            }
        )
    out.sort(key=lambda x: x["rank"])
    return out


async def by_area(signgu_cd: str, *, rows: int = 100, session_id: str | None = None) -> list[dict]:
    signgu_cd = await api_code(signgu_cd)
    items, _ = await client.call(
        "TarRlteTarService1/areaBasedList1",
        {
            "baseYm": settings.tarrltetar_base_ym,
            "areaCd": signgu_cd[:2],
            "signguCd": signgu_cd,
            "numOfRows": rows,
            "pageNo": 1,
        },
        ttl=86400,
        session_id=session_id,
    )
    return [
        {"base": r.get("tAtsNm"), "name": r.get("rlteTatsNm"), "rank": int(r.get("rlteRank") or 999)}
        for r in items
        if r.get("rlteTatsNm")
    ]
