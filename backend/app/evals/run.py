from __future__ import annotations

import argparse
import asyncio
import json
import logging
import re
import time
from pathlib import Path

from app.agent import graph, guard
from app.core.config import settings
from app.evals import checks
from app.repository import db
from app.services import area, client

log = logging.getLogger("tour.evals")

CASES = [
    {
        "id": "단일혼잡도",
        "q": "경주 불국사 이번 토요일 붐빌까?",
        "tools": ["resolve_area", "find_attraction", "get_crowding"],
        "must_say": ["예측"],
    },
    {
        "id": "대안추천",
        "q": "경주 불국사 붐비면 한적한 데 추천해줘",
        "tools": ["resolve_area", "find_attraction", "get_crowding", "recommend_alternatives"],
        "must_say": ["예측"],
    },
    {
        "id": "지역현황",
        "q": "경주 요즘 어때?",
        "tools": ["resolve_area", "get_crowding"],
        "must_state_coverage": True,
        "no_codes": True,
    },
    {
        "id": "맥락후속",
        "q": "거기는 다음 주에 어때?",
        "history": [
            {"role": "user", "content": "경주 불국사 붐빌까?"},
            {"role": "assistant", "content": "불국사는 오늘 58.1로 보통입니다."},
        ],
        "resolved": {
            "signgu_cd": "47130",
            "signgu_nm": "경주시",
            "last_content_id": "126166",
            "last_content_name": "경주 불국사 [유네스코 세계유산]",
        },
        "tools": ["get_crowding"],
    },
    {
        "id": "없는관광지",
        "q": "경주 없는관광지1234 붐벼?",
        "tools": ["find_attraction"],
        "no_hallucination": True,
    },
    {
        "id": "동명지역",
        "q": "고성 어때?",
        "expect_ask_back": True,
        "no_codes": True,
    },
    {
        "id": "범위밖",
        "q": "오늘 서울 날씨 알려줘",
        "expect_refuse": True,
    },
]


async def run_one(case: dict) -> dict:
    session_id = f"eval-{case['id']}"
    await db.delete_session(session_id)
    await db.ensure_session(session_id, "eval-user", case["q"])
    if case.get("resolved"):
        await db.save_resolved(session_id, case["resolved"])

    session = await db.get_session(session_id)
    started = time.monotonic()
    first_status = None
    called: list[str] = []
    cards: list[dict] = []
    answer = ""

    unknown: list = []
    async for event, data in graph.run(
        case["q"], case.get("history", []), session_id, session
    ):
        if event == "status" and first_status is None:
            first_status = time.monotonic() - started
        elif event == "tool":
            called.append(data["name"])
        elif event == "card":
            cards.append(data)
        elif event == "final":
            answer = data["text"]
            unknown = data["unknown_numbers"]
        elif event == "error":
            return {"id": case["id"], "error": data.get("message")}

    elapsed = time.monotonic() - started
    missing = [t for t in (case.get("tools") or []) if t not in called]

    omitted = []
    for word in case.get("must_say", []):
        if word not in answer:
            omitted.append(word)
    for pat in case.get("must_match", []):
        if not re.search(pat, answer):
            omitted.append(pat)
    if case.get("must_state_coverage"):
        cov = checks.crowd_coverage(cards)
        if not cov:
            omitted.append("coverage(카드에 없음)")
        elif not checks.coverage_stated(answer, cov):
            omitted.append(
                f"coverage {cov.get('with_crowd_data')}/{cov.get('tourapi_total')}"
            )

    ok_ask = True
    if case.get("expect_ask_back"):
        ok_ask = "?" in answer or "어느" in answer or "말씀" in answer
    ok_refuse = True
    if case.get("expect_refuse"):
        ok_refuse = not cards and ("관광" in answer or "여행" in answer)

    leaked_codes = []
    if case.get("no_codes"):
        leaked_codes = [c for c in re.findall(r"\b\d{5}\b", answer)]

    return {
        "id": case["id"],
        "tools_called": called,
        "tools_missing": missing,
        "unknown_numbers": unknown,
        "omitted": omitted,
        "leaked_codes": leaked_codes,
        "ask_back_ok": ok_ask,
        "refuse_ok": ok_refuse,
        "first_status_s": round(first_status or 0, 2),
        "elapsed_s": round(elapsed, 1),
        "answer": answer,
    }


def score(results: list[dict]) -> dict:
    n = len(results)
    errs = [r for r in results if r.get("error")]
    good = [r for r in results if not r.get("error")]
    return {
        "cases": n,
        "failed": len(errs),
        "tool_accuracy": round(
            sum(1 for r in good if not r["tools_missing"]) / max(len(good), 1), 2
        ),
        "number_match_rate": round(
            sum(1 for r in good if not r["unknown_numbers"]) / max(len(good), 1), 2
        ),
        "omission_rate": round(
            sum(1 for r in good if r["omitted"]) / max(len(good), 1), 2
        ),
        "code_leaks": sum(1 for r in good if r.get("leaked_codes")),
        "ask_back_ok": all(r["ask_back_ok"] for r in good),
        "refuse_ok": all(r["refuse_ok"] for r in good),
        "first_status_max_s": round(max((r["first_status_s"] for r in good), default=0), 2),
        "elapsed_max_s": round(max((r["elapsed_s"] for r in good), default=0), 1),
    }


async def main() -> None:
    p = argparse.ArgumentParser(prog="evals")
    p.add_argument("--only", help="이 id 만 돌린다")
    p.add_argument("--wait", type=float, default=25, help="케이스 사이 대기 (무료 티어 한도)")
    args = p.parse_args()

    if not settings.llm_enabled:
        log.error("LLM_API_KEY 없음")
        return

    await db.init()
    await area.ensure_loaded()
    await client.load_today_count()

    cases = [c for c in CASES if not args.only or c["id"] == args.only]
    results = []
    for i, c in enumerate(cases):
        log.info("[%d/%d] %s", i + 1, len(cases), c["id"])
        try:
            r = await run_one(c)
        except Exception as e:
            r = {"id": c["id"], "error": f"{type(e).__name__}: {e}"}
        results.append(r)
        bad = (r.get("error") or r.get("tools_missing") or r.get("omitted")
               or r.get("leaked_codes") or r.get("unknown_numbers"))
        mark = "!!" if bad else "ok"
        log.info("%s %s", mark, str(r.get("answer", r.get("error")))[:110])
        if i < len(cases) - 1:
            await asyncio.sleep(args.wait)

    s = score(results)
    log.info("%s", json.dumps(s, ensure_ascii=False, indent=1))

    out = Path(__file__).parent / "last_run.json"
    out.write_text(
        json.dumps({"score": s, "results": results}, ensure_ascii=False, indent=1),
        encoding="utf-8",
    )
    log.info("결과 파일: %s", out)

    if s["tool_accuracy"] < 0.8 or s["number_match_rate"] < 0.9:
        log.warning("기준 미달로 배포하지 않는다")
    await client.close_client()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(main())
