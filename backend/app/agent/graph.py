from __future__ import annotations

import asyncio
import json
import logging
import re
from datetime import timedelta
from typing import AsyncIterator

from app.agent import compose, guard, llm, prompts, tools
from app.core import clock
from app.core.config import settings
from app.services import client as upstream
from app.repository import db

log = logging.getLogger("tour.agent")

MAX_TOOL_CALLS_PER_ROUND = 4

_CROWD_WORDS = ("붐", "혼잡", "한적", "조용", "사람", "추천", "어때", "현황", "가도",
                "아무", "알아서")

_ALT_WORDS = ("한적", "대안", "추천", "조용", "덜 붐", "안 붐", "다른 곳", "다른 데", "피해")

def needs_crowding(text: str) -> bool:
    return any(w in text for w in _CROWD_WORDS)


def wants_alternatives(text: str) -> bool:
    return any(w in text for w in _ALT_WORDS)

_WEEKDAY = ["월", "화", "수", "목", "금", "토", "일"]

def system_prompt(phase: str = "tool") -> str:
    today = clock.today()
    sat = today + timedelta(days=(5 - today.weekday()) % 7)
    tail = prompts.SYSTEM_TOOLS if phase == "tool" else prompts.SYSTEM_WRITE
    return (prompts.SYSTEM_HEAD + chr(10) * 2 + tail).format(
        today=today.isoformat(),
        weekday=_WEEKDAY[today.weekday()],
        saturday=sat.isoformat(),
        sunday=(sat + timedelta(days=1)).isoformat(),
    )


def remember(resolved: dict, name: str, result: dict) -> None:
    if result.get("status") != "ok":
        return
    if name == "resolve_area":
        resolved["signgu_cd"] = result.get("signgu_cd")
        resolved["signgu_nm"] = result.get("signgu_nm")
    elif name == "find_attraction" and result.get("items"):
        top = result["items"][0]
        resolved["last_content_id"] = top.get("content_id")
        resolved["last_content_name"] = top.get("title")
    elif name == "recommend_alternatives" and result.get("items"):
        resolved["last_alternatives"] = [i["name"] for i in result["items"][:3]]


def limit_event(e: llm.RateLimited) -> dict:
    return {
        "code": "LLM_QUOTA_EXHAUSTED" if e.daily else "LLM_RATE_LIMITED",
        "message": "오늘 쓸 수 있는 대화량을 다 썼어요. 내일 다시 시도해주세요."
        if e.daily
        else "지금 요청이 몰려 있어요. 잠시 후 다시 시도해주세요.",
        "retriable": not e.daily,
    }


def has(results: list, kind: str) -> bool:
    for r in results:
        if not isinstance(r, dict):
            continue
        if kind == "crowding" and (
            any(isinstance(i, dict) and "series" in i for i in r.get("items") or [])
            or "summary" in r
            or "samples" in r
        ):
            return True
    return False


async def optimize(text: str, context: str) -> str:
    if len(text) > 40:
        return text
    try:
        msg = await asyncio.wait_for(
            llm.complete(
                [
                    {
                        "role": "user",
                        "content": prompts.OPTIMIZER.format(
                            context=context or "(없음)", text=text
                        ),
                    }
                ],
                model=settings.llm_model_light,
                temperature=0,
                max_tokens=120,
                purpose="optimize",
            ),
            timeout=settings.optimizer_timeout,
        )
        out = (msg.get("content") or "").strip().strip('"')
        return out if 0 < len(out) <= 200 else text
    except Exception:
        return text

_TOKEN = re.compile(r"[가-힣A-Za-z0-9]+")

_JOSA = (
    "에서는", "으로는", "이라는", "까지", "부터", "에서", "에게", "이나", "라는",
    "이랑", "으로", "한테", "보다", "처럼", "마다", "조차", "밖에",
    "은", "는", "이", "가", "을", "를", "에", "의", "도", "만", "랑", "와", "과",
    "나", "요", "야", "여", "로",
)

def strip_josa(w: str) -> str:
    for j in _JOSA:
        if len(w) > len(j) + 1 and w.endswith(j):
            return w[: -len(j)]
    return w

def restore_name(asked: str, message: str) -> str:
    if not asked:
        return asked
    for w in _TOKEN.findall(message):
        core = strip_josa(w)
        if core != asked and len(core) > len(asked) and asked in core:
            return core
    return asked


_SIDO_WORDS = (
    "서울", "경기", "경기도", "인천", "강원", "강원도", "충북", "충남", "충청도", "충청북도",
    "충청남도", "전북", "전남", "전라도", "전라북도", "전라남도", "경북", "경남", "경상도",
    "경상북도", "경상남도", "제주", "제주도", "부산", "대구", "광주", "대전", "울산", "세종",
)


def restore_region(asked: str, message: str) -> str:
    """모델이 "전라도 광주" 에서 "광주" 만 넘기면 앞의 시도 표현을 되살린다. 동명 지역 되묻기를 줄인다."""
    if not asked or " " in asked:
        return asked
    raw = _TOKEN.findall(message)
    for i in range(1, len(raw)):
        if strip_josa(raw[i]) == asked and raw[i - 1] in _SIDO_WORDS and raw[i - 1] != asked:
            return f"{raw[i - 1]} {asked}"
    return asked


def args(raw: str) -> dict | None:
    try:
        v = json.loads(raw or "{}")
        return v if isinstance(v, dict) else None
    except json.JSONDecodeError:
        return None


VISITOR_LABEL = {"local": "현지인", "outsider": "외지인", "foreigner": "외국인", "other": "기타"}


def for_model(name: str, result: dict) -> dict:
    st = result.get("status")
    base: dict = {"status": st}
    for k in ("message", "hint", "signgu_nm", "signgu_cd", "coverage", "date", "summary",
              "has_crowd_data"):
        if k in result:
            base[k] = result[k]

    if name == "resolve_area":
        if result.get("status") == "ambiguous":
            return {
                "status": "ambiguous",
                "candidates": [c["label"] for c in result.get("candidates", [])],
                "instruction": "후보 이름만 보여주고 어느 곳인지 되물어라. 코드는 말하지 마라.",
            }
        drop = ("aliases", "area_cd", "tour_cd", "legacy_cd")
        out = {k: v for k, v in result.items() if k not in drop}
        if out.get("has_crowd_data") is None:
            out.pop("has_crowd_data", None)
        return out

    if name == "find_attraction":
        base["confident"] = result.get("confident")
        n = 1 if result.get("confident") else 5
        base["items"] = [
            {"content_id": i["content_id"], "title": i["title"], "addr1": i.get("addr1", "")}
            for i in (result.get("items") or [])[:n]
        ]
        return base

    if name == "get_crowding":
        items = []
        for i in (result.get("items") or [])[:8]:
            s = i.get("series") or []
            items.append(
                {
                    "name": i.get("name"),
                    "match_method": i.get("match_method"),
                    "by_day": [
                        {"date": d["date"], "weekday": d["weekday"], "rate": d["rate"],
                         "level": d["level"]}
                        for d in s[:8]
                    ],
                    "summary": i.get("summary"),
                    "days_available": i.get("available_days"),
                }
            )
        if items:
            base["items"] = items
        if result.get("unmatched"):
            base["unmatched"] = result["unmatched"][:5]
        if isinstance(base.get("summary"), dict):
            base["places_by_level"] = base.pop("summary")
        sam = result.get("samples")
        if isinstance(sam, dict):
            base["samples"] = {k: v[: (6 if k == "quiet" else 3)] for k, v in sam.items()}
        return base

    if name == "recommend_alternatives":
        base["base"] = result.get("base")
        base["sort_basis"] = result.get("sort_basis")
        base["relaxed"] = result.get("relaxed")
        base["candidate_source"] = result.get("candidate_source")
        base["items"] = [
            {
                "name": i["name"],
                "rate": i["rate"],
                "level": i["level"],
                "lower_by": (i.get("reason") or {}).get("lower_by"),
                "distance_km": (i.get("reason") or {}).get("distance_km"),
                "same_category": (i.get("reason") or {}).get("same_category"),
            }
            for i in (result.get("items") or [])[:4]
        ]
        return base

    if name == "list_places":
        base["category"] = result.get("category")
        base["items"] = [
            {"title": i["title"], "addr1": i.get("addr1", "")}
            for i in (result.get("items") or [])[:8]
        ]
        return base

    if name == "find_pet_friendly":
        base["items"] = [
            {"title": i["title"], "pet_note": i.get("note", ""), "addr1": i.get("addr1", "")}
            for i in (result.get("items") or [])[:8]
        ]
        return base

    if name == "list_festivals":
        base["items"] = [
            {"title": i["title"], "period": i.get("period", ""), "addr1": i.get("addr1", "")}
            for i in (result.get("items") or [])[:8]
        ]
        return base

    if name == "get_interest_trend":
        base["items"] = [
            {"name": i.get("display_name") or i.get("name"), "trend": i["trend"],
             "change_pct": i["change_pct"]}
            for i in (result.get("items") or [])[:5]
        ]
        return base

    if name == "get_attraction_detail":
        base.update(
            {
                "title": result.get("title"),
                "addr1": result.get("addr1"),
                "info": result.get("info"),
                "pet": result.get("pet") or "정보 없음",
                "overview": guard.wrap_external((result.get("overview") or "")[:400]),
            }
        )
        return base

    if name == "get_area_visitors":
        items = result.get("items") or []
        base["data_through"] = result.get("data_through")
        base["recent"] = [{VISITOR_LABEL.get(k, k): v for k, v in i.items()} for i in items[-3:]]
        base["note"] = result.get("note")
        return base

    return base


async def summarize(history: list[dict], prev: str = "") -> str:
    text = "\n".join(f"{h['role']}: {h['content'][:200]}" for h in history)
    if prev:
        text = f"(이전 대화 요약) {prev}\n{text}"
    try:
        msg = await asyncio.wait_for(
            llm.complete(
                [{"role": "user", "content": prompts.SUMMARY.format(history=text)}],
                model=settings.llm_model_light,
                temperature=0,
                max_tokens=200,
                purpose="summary",
            ),
            timeout=4.0,
        )
        return (msg.get("content") or "").strip()
    except Exception:
        return ""


_summary_tasks: set[asyncio.Task] = set()
_summary_busy: set[str] = set()


def schedule_summary_merge(session_id: str, fresh: list[dict], prev: str) -> None:
    if session_id in _summary_busy:
        return
    ids = [h.get("id") or 0 for h in fresh]
    if not any(ids):
        return

    async def merge() -> None:
        try:
            merged = await summarize(fresh, prev)
            if merged:
                await db.save_summary(session_id, merged, max(ids))
        except Exception:
            log.warning("요약 병합 실패: %s", session_id)
        finally:
            _summary_busy.discard(session_id)

    _summary_busy.add(session_id)
    t = asyncio.create_task(merge())
    _summary_tasks.add(t)
    t.add_done_callback(_summary_tasks.discard)


async def run(
    message: str, history: list[dict], session_id: str, session: dict | None = None
) -> AsyncIterator[tuple[str, dict]]:
    session = session or {}
    raw_n = settings.context_raw_turns

    recent = history[-raw_n:]
    older = history[:-raw_n]
    summary = session.get("summary") or ""
    covered = int(session.get("summary_upto") or 0)
    fresh = [h for h in older if (h.get("id") or 0) > covered]
    if fresh:
        schedule_summary_merge(session_id, fresh, summary)

    ctx = "\n".join(
        f"{h['role']}: {h['content'][:120]}" for h in (fresh[-4:] + recent)
    )

    yield "status", {"stage": "optimizing", "label": "질문 이해 중"}
    optimized = await optimize(message, ctx)

    messages: list[dict] = [{"role": "system", "content": system_prompt("tool")}]
    if summary:
        messages.append({"role": "system", "content": f"앞선 대화 요약:\n{summary}"})

    resolved = session.get("resolved") or {}
    if resolved:
        messages.append(
            {
                "role": "system",
                "content": "직전에 확정된 대상입니다. 사용자가 '거기', '그곳'이라고 하면 "
                "이걸 가리킵니다. 수치는 새로 조회하세요.\n"
                + json.dumps(resolved, ensure_ascii=False),
            }
        )
    if ctx:
        messages.append({"role": "system", "content": f"직전 대화:\n{ctx}"})
    messages.append({"role": "user", "content": optimized})

    tool_results: list = []
    cards_out: list[dict] = []
    upstream.begin_budget()
    seen_calls: dict[str, object] = {}
    called_names: set[str] = set()
    bad_arg_names: set[str] = set()
    nudged = False

    for _round in range(settings.max_tool_rounds):
        try:
            msg = await llm.complete(messages, tools=tools.SCHEMA)
        except llm.RateLimited as e:
            log.warning("모델 호출 한도 초과: %s", e)
            if cards_out:
                try:
                    said = compose.from_cards(cards_out, message)
                except Exception:
                    said = ""
                if said:
                    for i in range(0, len(said), 16):
                        yield "delta", {"text": said[i : i + 16]}
                    await db.save_resolved(session_id, resolved)
                    yield "final", {"text": said, "unknown_numbers": []}
                    return
            yield "error", limit_event(e)
            return
        except llm.Unparsable:
            log.warning("도구 호출 생성 실패로 기존 결과로 응답")
            messages.append(
                {"role": "system", "content": "도구를 부르지 말고 지금까지 결과로 문장만 써라."}
            )
            break
        except RuntimeError as e:
            log.warning("LLM 호출 실패: %s", e)
            if cards_out:
                try:
                    said = compose.from_cards(cards_out, message)
                except Exception:
                    said = ""
                if said:
                    for i in range(0, len(said), 16):
                        yield "delta", {"text": said[i : i + 16]}
                    await db.save_resolved(session_id, resolved)
                    yield "final", {"text": said, "unknown_numbers": []}
                    return
            yield "error", {
                "code": "LLM_ERROR",
                "message": "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.",
                "retriable": True,
            }
            return

        calls = msg.get("tool_calls") or []
        cut = msg.get("finish_reason") == "length"
        if not calls:
            said = (msg.get("content") or "").strip()

            if cut and said:
                log.warning("max_tokens 초과로 응답이 잘려 compose로 전환")
                break

            if not nudged:
                todo = []
                if needs_crowding(message) and not has(tool_results, "crowding"):
                    todo.append("get_crowding")
                if wants_alternatives(message) and "recommend_alternatives" not in called_names:
                    todo.append("recommend_alternatives")
                if todo:
                    nudged = True
                    messages.append(
                        {
                            "role": "system",
                            "content": f"아직 {', '.join(todo)} 를 부르지 않았다. "
                            "사용자가 요청한 것이니 조회하고 답하라.",
                        }
                    )
                    continue

            if not said and cards_out:
                said = compose.from_cards(cards_out, message)
                log.info("모델 빈 응답으로 카드 기반 문장 생성")

            if said:
                said = guard.strip_codes(said)
                yield "status", {"stage": "composing", "label": "정리하는 중"}
                for i in range(0, len(said), 16):
                    yield "delta", {"text": said[i : i + 16]}
                odd = guard.unknown_numbers(said, tool_results, message)
                if odd:
                    log.warning("조회 결과에 없는 숫자 포함: %s", odd[:8])
                await db.save_resolved(session_id, resolved)
                yield "final", {"text": said, "unknown_numbers": odd}
                return
            break

        picked = calls[:MAX_TOOL_CALLS_PER_ROUND]
        messages.append(
            {
                "role": "assistant",
                "content": msg.get("content") or "",
                "tool_calls": picked,
            }
        )

        for c in picked:
            stage, label = tools.STAGE_OF.get(
                c["function"]["name"], ("composing", "정리하는 중")
            )
            yield "status", {"stage": stage, "label": label}

        async def call_one(c, truncated: bool):
            name = c["function"]["name"]
            params = args(c["function"].get("arguments"))
            if params is None or truncated:
                log.warning("도구 호출 파라미터 신뢰 불가: %s (잘림=%s)", name, truncated)
                if name in bad_arg_names:
                    return c, {
                        "status": "bad_arguments",
                        "message": "이 도구 호출이 계속 잘린다. 다시 부르지 말고 "
                        "지금까지 결과로 답하라.",
                    }, False
                bad_arg_names.add(name)
                return c, {
                    "status": "bad_arguments",
                    "message": "인자가 잘려서 읽지 못했다. 인자를 더 짧게 만들어 "
                    "이 도구를 다시 호출하라.",
                }, False
            if name == "find_attraction" and params.get("name"):
                params["name"] = restore_name(str(params["name"]), message)
            if name == "resolve_area" and params.get("query"):
                params["query"] = restore_region(str(params["query"]).strip(), message)
            key = f"{name}:{json.dumps(params, sort_keys=True, ensure_ascii=False)}"
            if key in seen_calls:
                prior = seen_calls[key]
                res = await prior if isinstance(prior, asyncio.Task) else prior
                return c, res, True
            if upstream.budget_exhausted():
                return c, {"status": "budget_exceeded", "message": "조회 한도에 걸렸다"}, False
            task = asyncio.ensure_future(tools.run(name, params, session_id))
            seen_calls[key] = task
            res = await task
            seen_calls[key] = res
            return c, res, False

        done = await asyncio.gather(
            *[call_one(c, cut and c is calls[-1]) for c in picked]
        )
        for c, result, repeated in done:
            name = c["function"]["name"]
            if not repeated:
                tool_results.append(result)

            if result.get("status") != "bad_arguments":
                called_names.add(name)
            remember(resolved, name, result)
            yield "tool", {"name": name, "status": result.get("status"), "repeated": repeated}

            card_type = tools.CARD_OF.get(name)
            if card_type and not repeated and result.get("status") in ("ok", "no_data"):
                card = {"type": card_type, "payload": result}
                cards_out.append(card)
                yield "card", card

            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": c.get("id", name),
                    "name": name,
                    "content": json.dumps(for_model(name, result), ensure_ascii=False)[:2500],
                }
            )
    else:
        msg = "이제 도구를 더 부르지 말고 지금까지 받은 결과로 답하라."
        if upstream.budget_exhausted():
            msg += " 조회 한도에 걸려 일부만 확인했다는 것도 밝혀라."
        messages.append({"role": "system", "content": msg})

    messages[0] = {"role": "system", "content": system_prompt("write")}
    yield "status", {"stage": "composing", "label": "정리하는 중"}

    for attempt in range(2):
        buf = ""
        chunks: list[str] = []
        bad = False
        try:
            async for piece in llm.stream(messages):
                buf += piece
                if not chunks and guard.leaked(buf):
                    bad = True
                    break
                if len(buf) >= 28:
                    out = guard.strip_codes(buf[:-12])
                    buf = buf[-12:]
                    if out:
                        chunks.append(out)
                        yield "delta", {"text": out}
        except llm.RateLimited as e:
            log.warning("compose 호출 한도 초과: %s", e)
            yield "error", limit_event(e)
            return
        except RuntimeError as e:
            log.warning("compose 호출 실패: %s", e)
            bad = True

        if bad and attempt == 0 and not chunks:
            messages.append(
                {"role": "system", "content": "도구를 부르지 말고 지금까지 결과로 문장만 써라."}
            )
            continue

        if buf:
            out = guard.strip_codes(buf)
            if out:
                chunks.append(out)
                yield "delta", {"text": out}

        answer = "".join(chunks).strip()

        if not answer and attempt == 0:
            log.info("빈 응답으로 1회 재시도")
            messages.append(
                {"role": "system",
                 "content": "방금 응답이 비어 있었다. 도구 결과를 바탕으로 사용자에게 "
                 "한국어 문장으로 답하라."}
            )
            continue

        if not answer:
            answer = compose.from_cards(cards_out, message)
            log.info("모델 빈 응답으로 카드 기반 문장 생성")
            for i in range(0, len(answer), 16):
                yield "delta", {"text": answer[i : i + 16]}

        odd = guard.unknown_numbers(answer, tool_results, message)
        if odd:
            log.warning("조회 결과에 없는 숫자 포함: %s", odd[:8])
        await db.save_resolved(session_id, resolved)
        yield "final", {"text": answer, "unknown_numbers": odd}
        return

    yield "error", {
        "code": "LLM_ERROR",
        "message": "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.",
        "retriable": True,
    }
