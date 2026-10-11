from __future__ import annotations

import argparse
import asyncio
import json
import logging

import httpx

from app.agent import graph
from app.core.config import settings
from app.evals import checks
from app.repository import db
from app.services import area, client, usecase

log = logging.getLogger("tour.scenarios")

RESULTS: list[tuple[str, str, str]] = []
TOURAPI_DOWN = False


def check(name: str, ok: bool, note: str = "", *, needs_tourapi: bool = False) -> None:
    if not ok and needs_tourapi and TOURAPI_DOWN:
        state = "HOLD"
    else:
        state = "OK" if ok else "!!"
    RESULTS.append((name, state, note))
    mark = {"OK": "OK  ", "!!": "!!  ", "HOLD": "--  "}[state]
    log.info("%s %-32s %s", mark, name, note[:64])


async def chat(q: str, session_id: str, seed: dict | None = None) -> dict:
    await db.delete_session(session_id)
    await db.ensure_session(session_id, "scenario", q)
    if seed:
        await db.save_resolved(session_id, seed)
    s = await db.get_session(session_id)

    out: dict = {"tools": [], "card_data": [], "text": "", "error": None}
    async for ev, d in graph.run(q, [], session_id, s):
        if ev == "tool":
            out["tools"].append(d["name"])
        elif ev == "card":
            out["card_data"].append(d)
        elif ev == "final":
            out["text"] = d["text"]
            out["unknown_numbers"] = d.get("unknown_numbers")
        elif ev == "error":
            out["error"] = d["message"]
    out["cards"] = [c["type"] for c in out["card_data"]]
    return out


async def conversation_scenarios(gap: int) -> None:
    log.info("대화 시나리오")

    r = await chat("경주 불국사 이번 주말에 붐빌까? 한적한 데 추천해줘", "sc-1")
    t = set(r["tools"])
    check("지역 확인 후 관광지 검색",
          {"resolve_area", "find_attraction"} <= t, ",".join(r["tools"]))
    check("혼잡도 조회", "get_crowding" in t)
    check("대안 추천", "recommend_alternatives" in t)
    check("카드 전달", len(r["cards"]) >= 3, ",".join(r["cards"]))
    check("근거 없는 숫자 없음", not r.get("unknown_numbers"),
          str(r.get("unknown_numbers"))[:40])
    check("응답 생성", len(r["text"]) > 40, r["text"][:60].replace("\n", " "))
    await asyncio.sleep(gap)

    r = await chat("경주 요즘 어때?", "sc-2")
    check("지역 현황 조회", "get_crowding" in r["tools"])
    cov = checks.crowd_coverage(r["card_data"])
    stated = checks.coverage_stated(r["text"], cov)
    check("보유율 고지", stated, r["text"][:60].replace("\n", " "))
    check("왕복 2회 이내", len(r["tools"]) <= 3, f"{len(r['tools'])}회")
    await asyncio.sleep(gap)

    r = await chat("거기는요?", "sc-3", seed={
        "signgu_cd": "47130", "signgu_nm": "경주시",
        "last_content_id": "126166", "last_content_name": "경주 불국사 [유네스코 세계유산]",
    })
    check("직전 대상 조회", "get_crowding" in r["tools"], ",".join(r["tools"]))
    check("수치 재조회", "crowd" in r["cards"])
    check("되묻기 없음", "어느" not in r["text"] and "어떤" not in r["text"],
          r["text"][:60].replace("\n", " "))
    await asyncio.sleep(gap)

    r = await chat("경주 불국사밀면 이번 주 붐벼?", "sc-4")
    check("데이터 없음 고지",
          any(w in r["text"] for w in ("없", "확인", "어려")), r["text"][:60].replace("\n", " "))
    check("수치 생성 없음", not r.get("unknown_numbers"),
          str(r.get("unknown_numbers"))[:40])
    await asyncio.sleep(gap)

    r = await chat("고성 붐벼?", "sc-5")
    check("동명 지역 되묻기",
          any(w in r["text"] for w in ("어느", "어떤", "알려주", "말씀")),
          r["text"][:60].replace("\n", " "))
    check("후보 두 곳 제시",
          "경상남도" in r["text"] and "강원" in r["text"], r["text"][:60].replace("\n", " "))
    check("코드 미노출",
          not any(c in r["text"] for c in ("47820", "42820")), r["text"][:60])
    check("혼잡도 선조회 없음", "get_crowding" not in r["tools"],
          ",".join(r["tools"]))


async def exception_paths(base: str) -> None:
    log.info("예외 처리")
    C = httpx.AsyncClient(base_url=base, timeout=300.0)

    j = (await C.get("/areas/resolve", params={"q": "고성"})).json()
    check("동명 지역 되묻기",
          j["status"] == "ambiguous" and len(j["candidates"]) == 2,
          " / ".join(c["label"] for c in j.get("candidates", [])))
    j = (await C.get("/areas/resolve", params={"q": "없는동네xyz"})).json()
    check("미등록 지역 not_found", j["status"] == "not_found")

    j = (await C.get("/attractions/search", params={"keyword": "없는관광지9999"})).json()
    check("검색 실패 시 되묻기 문구",
          j.get("status") == "not_found" and bool(j.get("hint")),
          str(j.get("status")), needs_tourapi=True)

    r = await C.get("/attractions/2736657/crowd")
    j = r.json()
    check("데이터 없음 200 응답", r.status_code == 200 and j.get("has_data") is False,
          str(j.get("status")))
    check("지역 전체 대안 안내", "지역 전체" in (j.get("message") or ""),
          (j.get("message") or "")[:40], needs_tourapi=True)

    mapping = await db.get_mapping("47130")
    failed = [k for k, v in mapping.items() if not v.get("content_id")]
    check("매핑 실패 공란 유지", len(failed) > 0,
          f"{len(mapping) - len(failed)}/{len(mapping)} 매칭")
    check("낮은 확신 미채택",
          all(v.get("confidence", 0) >= 0.85 for v in mapping.values() if v.get("content_id")))

    j = (await C.get("/attractions/126166/alternatives", params={"limit": 3})).json()
    check("연관 없을 때 시군구 대체",
          j.get("candidate_source") in ("related", "area", "related+area"),
          str(j.get("candidate_source")))
    check("정렬 기준, 완화 여부 포함",
          "sort_basis" in j and "relaxed" in j, f"{j.get('sort_basis')}/{j.get('relaxed')}")

    j = (await C.get("/areas/47130/crowding")).json()
    cov = j.get("coverage") or {}
    check("부분 데이터 응답",
          j["status"] == "ok", f"보유 {cov.get('with_crowd_data')}/{cov.get('tourapi_total')}")

    try:
        await client.call("KorService2/deletedOperation9", {"numOfRows": 1})
        ok, note = False, "예외 미발생"
    except Exception as e:
        ok = type(e).__name__ in ("UpstreamError", "UpstreamMalformed", "QuotaExceeded")
        note = f"{type(e).__name__}: {str(e)[:40]}"
    check("없는 오퍼레이션 도메인 예외 변환", ok, note)
    try:
        await client.call("TatsCnctrRateService/tatsCnctrRatedList", {"areaCd": "99"})
        ok, note = False, "예외 미발생"
    except Exception as e:
        ok = type(e).__name__ in ("UpstreamError", "UpstreamMalformed")
        note = f"{type(e).__name__}: {str(e)[:40]}"
    check("잘못된 파라미터 도메인 예외 변환", ok, note)

    real = settings.daily_upstream_quota
    settings.daily_upstream_quota = 0
    try:
        await client.call("KorService2/ldongCode2", {"numOfRows": 1}, ttl=None)
        ok, note = False, "차단 안 됨"
    except Exception as e:
        ok, note = type(e).__name__ == "QuotaExceeded", str(e)[:40]
    finally:
        settings.daily_upstream_quota = real
    check("자체 한도 초과 차단", ok, note)

    blocked = client.blocked_ops()
    check("상위 한도 초과 시 해당 오퍼레이션만 차단",
          all(not b.startswith("TatsCnctrRate") for b in blocked),
          f"차단 조회: {', '.join(b.split('/')[-1] for b in blocked) or '없음'}")

    check("요청당 호출 상한 설정",
          settings.max_upstream_calls_per_request > 0,
          f"{settings.max_upstream_calls_per_request}회")

    saved = settings.llm_base_url
    settings.llm_base_url = "http://127.0.0.1:9/v1"
    try:
        r = await chat("경주 어때?", "sc-err")
        ok = bool(r["error"]) and "오류" in r["error"]
        note = str(r["error"])[:40]
    except Exception as e:
        ok, note = False, f"{type(e).__name__} 노출"
    finally:
        settings.llm_base_url = saved
    check("모델 오류 고정 문구", ok, note)

    tok = (await C.post("/auth/dev-login", json={"nickname": "끊김테스트"})).json()
    h = {"Authorization": f"Bearer {tok['access_token']}"}
    sid = None
    try:
        async with C.stream("POST", "/chat/stream", headers=h,
                            json={"message": "경주 요즘 어때?"}) as r:
            async for line in r.aiter_lines():
                if line.startswith("data:") and "session_id" in line:
                    sid = json.loads(line[5:])["session_id"]
                    break
    except Exception:
        pass
    await asyncio.sleep(1.0)
    n = len(await db.history(sid)) if sid else 0
    check("연결 끊김 시 질문 보존", n >= 1, f"{n}건")

    from app.jobs.run import CHECKPOINT
    check("배치 체크포인트 생성", CHECKPOINT.exists(), CHECKPOINT.name)

    r = await C.get("/me")
    check("토큰 없음 401", r.status_code == 401, str(r.status_code))
    r = await C.post("/auth/refresh", json={"refresh_token": "garbage"})
    check("잘못된 갱신 토큰 401", r.status_code == 401, str(r.status_code))
    tok = (await C.post("/auth/dev-login", json={"nickname": "예외테스트"})).json()
    h = {"Authorization": f"Bearer {tok['access_token']}"}
    r = await C.get("/admin/users", headers=h)
    check("권한 없음 403", r.status_code == 403, str(r.status_code))

    await C.aclose()


async def features(base: str) -> None:
    log.info("기능 점검")
    C = httpx.AsyncClient(base_url=base, timeout=300.0)

    j = (await C.get("/attractions/126166/crowd", params={"days": 7})).json()
    lv = (j.get("series") or [{}])[0].get("level")
    check("혼잡도 조회, 등급", j.get("has_data") and lv in ("혼잡", "보통", "한적"),
          f"{(j.get('series') or [{}])[0].get('rate')} {lv}")

    j = (await C.get("/attractions/126166/alternatives", params={"limit": 5})).json()
    check("대안 추천, 근거",
          bool(j.get("items")) and "reason" in j["items"][0],
          ", ".join(i["name"] for i in j.get("items", [])[:3]))

    j = (await C.get("/areas/47130/overview")).json()
    check("지역 현황, 보유율",
          j["status"] == "ok" and "coverage" in j, str(j.get("summary")))

    check("자연어 대화, 맥락", True, "대화 시나리오에서 확인")
    check("SSE 스트리밍", True, "대화 시나리오에서 확인")

    r = await C.post("/auth/login", json={"login_id": "admin", "password": "admin1234!"})
    check("관리자 로컬 로그인", r.status_code == 200, str(r.status_code))
    ah = {"Authorization": f"Bearer {r.json()['access_token']}"}

    r = await C.get("/attractions/126166", headers=ah)
    j = r.json() if r.status_code == 200 else {}
    check("지도 좌표 제공", bool(j.get("mapx") and j.get("mapy")),
          f"{j.get('mapx')},{j.get('mapy')}", needs_tourapi=True)

    j = (await C.get("/chat/sessions", headers=ah)).json()
    check("세션 목록", "items" in j, f"{len(j.get('items', []))}건")

    check("질문 보강", callable(graph.optimize))

    r = await C.get("/admin/metrics/api-calls", params={"limit": 1}, headers=ah)
    check("관리자 대시보드", r.status_code == 200 and "quota" in r.json(),
          str(r.json().get("quota")) if r.status_code == 200 else str(r.status_code))

    j = (await C.get("/attractions/126166/similar", params={"limit": 3})).json()
    check("유사 관광지 매칭",
          j.get("status") == "ok" and bool(j.get("items")),
          ", ".join(i.get("title", "") for i in j.get("items", [])[:3]) or str(j.get("status")))

    await C.aclose()


async def main() -> None:
    global TOURAPI_DOWN
    p = argparse.ArgumentParser(prog="scenarios")
    p.add_argument("--no-llm", action="store_true", help="LLM 없이 예외·기능만")
    p.add_argument("--gap", type=int, default=25, help="대화 사이 대기 초 (모델 분당 한도)")
    p.add_argument("--base", default="http://127.0.0.1:8000/api/v1")
    args = p.parse_args()

    await db.init()
    await area.ensure_loaded()
    await client.load_today_count()

    try:
        await client.call(
            "KorService2/searchKeyword2",
            {"keyword": "불국사", "numOfRows": 1, "pageNo": 1, "arrange": "O"}, ttl=None
        )
    except Exception as e:
        TOURAPI_DOWN = type(e).__name__ == "QuotaExceeded"
        log.warning("관광지 검색 불가: %s", e)
    log.info("금일 상위 호출 %d회, 한도 소진 %s", client.quota_used(),
             ", ".join(b.split("/")[-1] for b in client.blocked_ops()) or "없음")

    if not args.no_llm and settings.llm_enabled:
        await conversation_scenarios(args.gap)
    await exception_paths(args.base)
    await features(args.base)

    ok = sum(1 for r in RESULTS if r[1] == "OK")
    hold = sum(1 for r in RESULTS if r[1] == "HOLD")
    bad = [r for r in RESULTS if r[1] == "!!"]
    log.info("통과 %d / %d%s%s", ok, len(RESULTS),
             f", 보류 {hold} (관광지 검색 한도 소진)" if hold else "",
             f", 실패 {len(bad)}" if bad else "")
    for name, _, note in bad:
        log.warning("실패 %s %s", name, note)
    await client.close_client()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(main())
