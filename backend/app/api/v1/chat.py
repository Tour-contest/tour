from __future__ import annotations

import asyncio
import json
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, field_validator

from app.agent import compose, guard
from app.core import response
from app.core.config import settings
from app.core.response import EnvelopeRoute
from app.core.deps import current_user
from app.repository import db
from app.schemas.chat import MessagesOut, SessionsOut
from app.schemas.common import Envelope, OkOut, errors, example
from app.services import usecase

log = logging.getLogger("tour.chat")

router = APIRouter(prefix="/chat", tags=["chat"], route_class=EnvelopeRoute)

STAGE_LABEL = {
    "optimizing": "질문 이해 중",
    "resolving": "위치 확인 중",
    "searching": "관광지 찾는 중",
    "crowd": "혼잡도 확인 중",
    "alternatives": "근처 한적한 곳 찾는 중",
    "overview": "지역 현황 보는 중",
    "composing": "정리하는 중",
}


SESSION_ID_PATTERN = r"^[0-9a-f]{12}$"
SESSION_PATH = Path(description="세션 식별자", pattern=SESSION_ID_PATTERN, examples=["a1b2c3d4e5f6"])


class ChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=500, description="사용자가 보낸 문장",
                         examples=["태안에 한적한 캠핑장 추천해줘"])
    session_id: str | None = Field(
        None, pattern=SESSION_ID_PATTERN,
        description="이어가는 대화의 세션. 새 대화면 비우고, meta 이벤트로 받은 값을 다음부터 쓴다. "
                    "서버가 발급한 12자리 hex 만 받는다",
        examples=["a1b2c3d4e5f6"],
    )

    @field_validator("session_id", mode="before")
    @classmethod
    def blank_is_new(cls, v):
        """빈 문자열은 새 대화로 본다. 앱이 새 대화일 때 "" 를 보낸다."""
        if isinstance(v, str) and not v.strip():
            return None
        return v


_SSE_EXAMPLE = (
    "event: meta\n"
    'data: {"session_id":"a1b2c3d4e5f6","message_id":"9f8e7d6c","title":"태안 한적한 캠핑장"}\n\n'
    "event: status\n"
    'data: {"stage":"searching","label":"관광지 찾는 중"}\n\n'
    "event: tool\n"
    'data: {"name":"list_places","status":"ok","repeated":false}\n\n'
    "event: card\n"
    'data: {"type":"attraction_list","payload":{"items":[{"content_id":"126266","title":"운여해변"}]}}\n\n'
    "event: delta\n"
    'data: {"text":"태안에서 지금 한적한 "}\n\n'
    "event: sources\n"
    'data: {"items":[{"name":"출처: ⓒ한국관광공사","note":""}]}\n\n'
    "event: final\n"
    'data: {"text":"태안에서 지금 한적한 야영장 세 곳을 추렸어요.","unknown_numbers":[]}\n\n'
    "event: done\n"
    'data: {"message_id":"9f8e7d6c","cards":2}\n\n'
)


def sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def clean(text: str) -> str:
    return "".join(ch for ch in text if ch == "\n" or ord(ch) >= 32)[:500]


def shown_attraction(cards: list[dict]) -> dict | None:
    for c in cards:
        p = c.get("payload") or {}
        if c.get("type") == "attraction" and p.get("content_id"):
            return p
        if c.get("type") == "attraction_list" and p.get("items"):
            if p.get("confident") or len(p["items"]) == 1:
                return p["items"][0]
    return None


def shown_level(cards: list[dict], content_id: str) -> str | None:
    for c in cards:
        if c.get("type") != "crowd":
            continue
        p = c.get("payload") or {}
        for i in p.get("items") or ([p] if p.get("series") else []):
            if i.get("content_id") == content_id and i.get("series"):
                return i["series"][0].get("level")
    return None


async def record_recent(user: dict, cards: list[dict]) -> None:
    a = shown_attraction(cards)
    if not a:
        return
    try:
        await db.touch_recent(
            user["id"],
            {
                "content_id": a["content_id"],
                "title": a.get("title") or "",
                "signgu_cd": a.get("signgu_cd"),
                "signgu_nm": a.get("signgu_nm"),
                "last_level": shown_level(cards, a["content_id"]),
            },
            settings.recent_attractions_limit,
        )
    except Exception:
        pass


async def run(body: ChatIn, user: dict):
    session_id = body.session_id or uuid.uuid4().hex[:12]
    message_id = uuid.uuid4().hex[:12]
    message = clean(body.message)

    session = await db.ensure_session(session_id, user["id"], message)
    if session["user_id"] != user["id"]:
        yield sse("error", {"code": "FORBIDDEN", "message": "볼 수 없는 대화입니다",
                            "retriable": False})
        return
    prev = _live.get(session_id)
    if prev is not None and not prev.done:
        yield sse("error", {"code": "CHAT_BUSY",
                            "message": "아직 답변을 만드는 중이에요. 끝난 뒤에 보내주세요.",
                            "retriable": True})
        return
    live = _Live()
    _live[session_id] = live

    def release() -> None:
        if _live.get(session_id) is live:
            del _live[session_id]

    try:
        await db.touch_session(session_id)
        await db.add_message(session_id, "user", message)
        await db.prune_sessions(user["id"], settings.max_sessions_per_user)

        yield sse("meta", {"session_id": session_id, "message_id": message_id,
                           "title": session["title"]})

        if guard.unsupported_topic(message):
            text = guard.UNSUPPORTED_TOPIC_ANSWER
            for chunk in chunks(text):
                yield sse("delta", {"text": chunk})
            await db.add_message(session_id, "assistant", text)
            yield sse("done", {"message_id": message_id, "cards": 0})
            return

        if settings.llm_enabled:
            async for chunk in run_llm(live, session_id, message_id, message, session, user):
                yield chunk
            return

        async for chunk in run_rules(session_id, message_id, message, user):
            yield chunk
    finally:
        if not settings.llm_enabled or guard.unsupported_topic(message):
            await live.close()
            release()


class _Live:
    def __init__(self) -> None:
        self.events: list[tuple[str, dict]] = []
        self.done = False
        self.cond = asyncio.Condition()

    async def put(self, event: str, data: dict) -> None:
        self.events.append((event, data))
        async with self.cond:
            self.cond.notify_all()

    async def close(self) -> None:
        async with self.cond:
            self.done = True
            self.cond.notify_all()

    async def follow(self):
        i = 0
        while True:
            while i < len(self.events):
                e, d = self.events[i]
                i += 1
                yield sse(e, d)
            async with self.cond:
                if i < len(self.events):
                    continue
                if self.done:
                    return
                await self.cond.wait()


_live: dict[str, _Live] = {}
_gen_tasks: set[asyncio.Task] = set()


async def generate(
    live: _Live, session_id: str, message_id: str, message: str, session: dict, user: dict
) -> None:
    from app.agent import graph

    text = ""
    cards: list[dict] = []
    try:
        history = await db.history(session_id, limit=20)
        async for event, data in graph.run(message, history[:-1], session_id, session):
            if event == "final":
                text = data["text"]
                continue
            if event == "card":
                cards.append(data)
            await live.put(event, data)
        if cards:
            await live.put("sources", {"items": [{"name": "출처: ⓒ한국관광공사", "note": ""}]})
        if text:
            await db.add_message(session_id, "assistant", text, cards)
        await record_recent(user, cards)
        await live.put("done", {"message_id": message_id, "cards": len(cards)})
    except Exception:
        log.exception("응답 생성 실패: %s", session_id)
        await live.put(
            "error",
            {
                "code": "INTERNAL_ERROR",
                "message": "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.",
                "retriable": True,
            },
        )
    finally:
        await live.close()
        if _live.get(session_id) is live:
            del _live[session_id]


async def run_llm(live: _Live, session_id: str, message_id: str, message: str,
                  session: dict, user: dict):
    t = asyncio.create_task(generate(live, session_id, message_id, message, session, user))
    _gen_tasks.add(t)
    t.add_done_callback(_gen_tasks.discard)
    async for frame in live.follow():
        yield frame


async def run_rules(session_id: str, message_id: str, message: str, user: dict):
    try:
        yield sse("status", {"stage": "optimizing", "label": STAGE_LABEL["optimizing"]})

        from app.agent.intent import parse_intent

        intent = parse_intent(message)
        if intent["tokens"]:
            yield sse(
                "status",
                {"stage": "resolving", "label": f"{intent['tokens'][0]} 위치 확인 중"},
            )

        task = asyncio.create_task(usecase.ask(message, session_id=session_id))

        stages = ["crowd", "alternatives", "composing"]
        i = 0
        while not task.done():
            await asyncio.sleep(1.2)
            if task.done():
                break
            if i < len(stages):
                yield sse("status", {"stage": stages[i], "label": STAGE_LABEL[stages[i]]})
                i += 1
            else:
                yield ": ping\n\n"

        result = await task

        for card in result.get("cards", []):
            yield sse("card", card)

        text = result.get("message") or compose.from_cards(result.get("cards", []), message)
        yield sse("status", {"stage": "composing", "label": STAGE_LABEL["composing"]})
        for chunk in chunks(text):
            yield sse("delta", {"text": chunk})
            await asyncio.sleep(0.02)

        if result.get("cards"):
            yield sse("sources", {"items": [{"name": result.get("source", ""), "note": ""}]})
        await db.add_message(session_id, "assistant", text, result.get("cards"))
        await record_recent(user, result.get("cards") or [])
        yield sse("done", {"message_id": message_id, "cards": len(result.get("cards", []))})

    except Exception:
        log.exception("규칙 기반 응답 실패: %s", session_id)
        yield sse(
            "error",
            {
                "code": "INTERNAL_ERROR",
                "message": "일시적인 오류가 발생했어요. 잠시 후 다시 시도해주세요.",
                "retriable": True,
            },
        )


def chunks(text: str, n: int = 18):
    for i in range(0, len(text), n):
        yield text[i : i + n]


@router.post(
    "/stream",
    summary="대화 전송 (SSE)",
    response_class=StreamingResponse,
    responses={
        200: {"description": "이벤트 스트림",
              "content": {"text/event-stream": {"schema": {"type": "string"},
                                                "example": _SSE_EXAMPLE}}},
        **errors("401", "422", "429"),
    },
)
async def stream(body: ChatIn, user: dict = Depends(current_user)):
    """이 경로만 공통 응답 형식을 따르지 않는다. text/event-stream 으로 이벤트가 순서대로 온다.

    POST 라 EventSource 를 못 쓴다. fetch + ReadableStream 으로 받을 것.

    | 이벤트 | 언제 | data |
    | --- | --- | --- |
    | `meta` | 맨 처음 한 번 | `{session_id, message_id, title}` |
    | `status` | 조회하는 동안 | `{stage, label}` |
    | `tool` | 도구를 하나 끝낼 때마다 | `{name, status, repeated}` |
    | `card` | 카드가 생길 때마다 | `{type, payload}` |
    | `delta` | 문장을 만드는 동안 | `{text}` (이어붙이면 전문) |
    | `sources` | 카드가 있을 때만 | `{items:[{name, note}]}` |
    | `final` | 문장이 끝나면 | `{text, unknown_numbers}` |
    | `done` | 맨 끝 | `{message_id, cards}` |
    | `error` | 실패 | `{code, message, retriable}` |

    같은 세션에서 답변을 만드는 중에 다시 보내면 `error` 의 code 가 `CHAT_BUSY` 로 오고
    메시지는 저장되지 않는다. 전송 버튼은 `done` 이나 `error` 를 받을 때까지 비활성으로 둔다.

    card 의 payload 는 그 카드를 만든 도구의 반환값 그대로다.

    | card.type | payload | 화면 |
    | --- | --- | --- |
    | attraction_list | {status, signgu_nm, items[{content_id, title, addr1, image, mapx, mapy, signgu_cd, period?, note?}]} | 상위 3개 목록. title·addr1, 탭하면 상세 |
    | crowd (관광지) | {status, signgu_nm, items[{content_id, name, matched_title, match_method, series[{date, weekday, rate, level}], summary, available_days}]} | 막대 그래프. summary 가 없으면 이 모양 |
    | crowd (지역) | GET /areas/{cd}/overview 응답과 같음 | summary 가 있으면 도넛 + 한적/인기 칩 |
    | alternatives | GET /attractions/{id}/alternatives 응답과 같음 | 상위 3개. reason.lower_by·distance_km·similarity 한 줄 |
    | interest | {status, items[{name, display_name, trend, change_pct, weeks}]} | trend 가 flat 이 아닐 때만 한 줄 안내 |
    | detail · attraction | GET /attractions/{id} 응답과 같음 | 단건 목록 카드 |
    | visitors | GET /areas/{cd}/visitors 응답과 같음 | 주별 막대 + data_through |
    | area_overview | GET /areas/{cd}/overview 응답과 같음. 규칙 기반 경로에서만 | 도넛 + 칩 |

    payload.status 가 no_data 이거나 has_data 가 false 면 카드 대신 "지역 전체 현황 보기"
    같은 후속 질문 버튼을 그린다. 카드는 status 가 ok 또는 no_data 일 때만 온다.
    단 payload.has_crowd_data 가 false 면 지역 자체에 집중률이 없는 것이라 그 버튼을 눌러도
    같은 결과가 온다. 이때는 버튼 없이 "이 지역은 아직 혼잡도가 제공되지 않는다" 한 줄만 보인다.

    새 대화면 `meta` 의 session_id 를 저장해 다음 메시지부터 같이 보낸다. 카드가 문장보다
    먼저 오니 도착하는 대로 그리면 된다. 문장 속 수치와 카드 속 수치가 다르면
    카드가 원본이다.

    자동 재연결 금지. 다시 부르면 같은 대화가 두 번 처리되면서 공공데이터 호출과
    모델 비용이 그대로 두 배가 된다. 재시도는 사용자가 버튼으로 한다. `done` 없이 끊기면
    미완성으로 두면 되고, 서버가 그때까지의 문장을 이력에 저장하므로 다시 들어와
    복원하면 이어져 보인다.

    분당 10회로 따로 묶여 있다.
    """
    return StreamingResponse(
        run(body, user),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no", "Connection": "keep-alive"},
    )


@router.get(
    "/sessions",
    summary="대화 세션 목록 조회",
    responses={200: {"model": Envelope[SessionsOut], "description": "성공", **example(
        {"items": [{"id": "a1b2c3d4e5f6", "title": "태안 한적한 캠핑장", "messages": 4,
                    "last_active_at": "2026-09-06T09:11:40+09:00"}],
         "page": {"limit": 30, "offset": 0, "total": 41, "has_more": True}})},
        **errors("401", "422", "429")},
)
async def sessions(
    user: dict = Depends(current_user),
    limit: int = Query(default=30, ge=1, le=100, description="한 번에 받을 개수"),
    offset: int = Query(default=0, ge=0, description="건너뛸 개수"),
):
    """최근 활동 순 대화 세션 목록.

    제목은 첫 사용자 메시지로 생성되므로 대화 종료 후 다시 조회한다.
    보관 개수 상한을 넘으면 오래된 세션부터 서버가 삭제한다.
    """
    items, total = await db.list_sessions(user["id"], limit, offset)
    return response.page(items, limit=limit, offset=offset, total=total)


async def owned(session_id: str, user: dict) -> dict:
    s = await db.get_session(session_id)
    if s is None:
        raise HTTPException(404, {"code": "NOT_FOUND", "message": "없는 대화입니다"})
    if s["user_id"] != user["id"] and user.get("role") != "admin":
        raise HTTPException(403, {"code": "FORBIDDEN", "message": "볼 수 없는 대화입니다"})
    return s


@router.get(
    "/sessions/{session_id}/messages",
    summary="대화 이력 조회",
    responses={200: {"model": Envelope[MessagesOut], "description": "성공", **example(
        {"items": [{"id": 8821, "session_id": "a1b2c3d4e5f6", "role": "user",
                    "content": "태안 한적한 캠핑장 추천해줘", "tool_trace": [],
                    "created_at": "2026-09-06T08:40:02+09:00"},
                   {"id": 8822, "session_id": "a1b2c3d4e5f6", "role": "assistant",
                    "content": "태안에서 지금 한적한 야영장 세 곳을 추렸어요.",
                    "tool_trace": [{"type": "attraction_list", "payload": {"items": []}}],
                    "created_at": "2026-09-06T08:40:31+09:00"}],
         "page": {"limit": 100, "has_more": True, "next_before": 8821}})},
        **errors("401", "403", "404", "422", "429",
                 messages={"403": "볼 수 없는 대화입니다",
                           "404": "없는 대화입니다"})},
)
async def messages(
    session_id: str = SESSION_PATH,
    user: dict = Depends(current_user),
    limit: int = Query(default=100, ge=1, le=200, description="한 번에 받을 개수"),
    before: int | None = Query(default=None, ge=1,
                               description="이 id 이전 메시지를 조회한다. page.next_before 를 그대로 넣는다"),
):
    """대화 이력. 본인 또는 관리자만 조회할 수 있다.

    이 엔드포인트만 before 커서를 사용한다. 조회 중에도 메시지가 늘어나기 때문에
    offset 을 쓰면 같은 메시지가 중복된다. page.next_before 를 before 로 넣으면
    이전 묶음을 이어 받는다.

    tool_trace 는 응답 당시 렌더된 카드 목록이라 화면을 그대로 복원할 수 있다.
    """
    await owned(session_id, user)
    items = await db.history(session_id, limit=limit, before=before)
    has_more = bool(items) and await db.history_has_more(session_id, items[0]["id"])
    return {
        "items": items,
        "page": {
            "limit": limit,
            "has_more": has_more,
            "next_before": items[0]["id"] if items and has_more else None,
        },
    }


@router.get(
    "/sessions/{session_id}/stream",
    summary="진행 중인 답변 이어받기 (SSE)",
    response_class=StreamingResponse,
    responses={
        200: {"description": "이벤트 스트림. POST /chat/stream 과 같은 형식",
              "content": {"text/event-stream": {"schema": {"type": "string"}}}},
        **errors("401", "403", "404", "429",
                 messages={"403": "볼 수 없는 대화입니다", "404": "없는 대화입니다"}),
    },
)
async def resume_stream(
    session_id: str = SESSION_PATH,
    user: dict = Depends(current_user),
):
    """새로고침 등으로 끊긴 뒤 다시 들어왔을 때 부른다.

    이 세션에 생성 중인 답변이 있으면 지금까지의 이벤트를 처음부터 재생한 뒤
    실시간으로 이어준다. 이벤트 형식은 POST /chat/stream 과 동일하다 (meta 없음).

    생성 중인 게 없으면(이미 끝났거나 실패) `done` 하나만 오고 닫힌다.
    끝난 답변은 대화 이력 조회에 저장돼 있으니 그쪽을 다시 부르면 된다.

    이 스트림은 이미 돌고 있는 생성을 구독만 하므로 몇 번을 다시 붙어도
    외부 조회나 모델 비용이 늘지 않는다.
    """
    await owned(session_id, user)
    live = _live.get(session_id)

    async def relay():
        if live is None:
            yield sse("done", {"message_id": "", "cards": 0})
            return
        async for frame in live.follow():
            yield frame

    return StreamingResponse(
        relay(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no",
                 "Connection": "keep-alive"},
    )


@router.delete(
    "/sessions/{session_id}",
    summary="대화 세션 삭제",
    responses={200: {"model": Envelope[OkOut], "description": "성공", **example({"ok": True})},
               **errors("401", "403", "404", "429",
                 messages={"403": "볼 수 없는 대화입니다",
                           "404": "없는 대화입니다"})},
)
async def delete_session(
    session_id: str = SESSION_PATH,
    user: dict = Depends(current_user),
):
    """세션과 해당 세션의 메시지를 삭제한다. 본인 또는 관리자만 가능하다."""
    await owned(session_id, user)
    await db.delete_session(session_id)
    return {"ok": True}
