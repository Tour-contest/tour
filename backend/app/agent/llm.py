from __future__ import annotations

import asyncio
import json
import logging
import re
import time
from typing import Any, AsyncIterator

import httpx

from app.core.config import settings
from app.services import client as upstream

log = logging.getLogger("tour.llm")

_WAIT = re.compile(r"try again in ([\d.]+)s", re.IGNORECASE)

usage: dict[str, int] = {"calls": 0, "prompt": 0, "completion": 0}

_log_tasks: set[asyncio.Task] = set()


def count(payload: dict) -> None:
    u = payload.get("usage") or {}
    usage["calls"] += 1
    usage["prompt"] += int(u.get("prompt_tokens") or 0)
    usage["completion"] += int(u.get("completion_tokens") or 0)


def log_call(model: str, purpose: str, payload: dict | None, latency_ms: int,
              status: str = "ok") -> None:
    u = (payload or {}).get("usage") or {}
    row = {
        "model": model,
        "purpose": purpose,
        "prompt_tokens": int(u.get("prompt_tokens") or 0),
        "completion_tokens": int(u.get("completion_tokens") or 0),
        "latency_ms": latency_ms,
        "status": status,
    }

    async def write():
        try:
            from app.repository import db
            await db.add_llm_log(row)
        except Exception:
            pass

    try:
        t = asyncio.get_running_loop().create_task(write())
        _log_tasks.add(t)
        t.add_done_callback(_log_tasks.discard)
    except RuntimeError:
        pass


class RateLimited(RuntimeError):
    def __init__(self, message: str, retry_after: float | None = None, *, daily: bool = False):
        super().__init__(message)
        self.retry_after = retry_after
        self.daily = daily


class Unparsable(RuntimeError):
    pass


def is_daily(text: str) -> bool:
    t = text or ""
    return "per day" in t or "TPD" in t or "RPD" in t


def retry_after(r: httpx.Response, attempt: int, text: str | None = None) -> float:
    hdr = r.headers.get("retry-after")
    if hdr:
        try:
            return min(float(hdr), 20.0)
        except ValueError:
            pass
    m = _WAIT.search(text if text is not None else (r.text or ""))
    if m:
        return min(float(m.group(1)) + 0.4, 20.0)
    return [2.0, 6.0][min(attempt, 1)]


def failed_generation(r: httpx.Response) -> str:
    try:
        return str(r.json()["error"].get("failed_generation"))[:300]
    except Exception:
        return r.text[:200]


_REASONING_PREFIX = ("gpt-5", "o1", "o3", "o4")


def adapt(body: dict) -> None:
    model = body.get("model") or ""
    eff = (settings.llm_reasoning_effort or "").strip().lower()
    if eff and "gpt-oss" in model:
        body["reasoning_effort"] = eff
    if model.startswith(_REASONING_PREFIX) and "-chat" not in model:
        if "max_tokens" in body:
            body["max_completion_tokens"] = body.pop("max_tokens")
        body.pop("temperature", None)
        if eff and "tools" not in body:
            body["reasoning_effort"] = eff


def handle_429(r: httpx.Response, text: str, attempt: int) -> float:
    if is_daily(text):
        raise RateLimited("금일 모델 사용량 소진", daily=True)
    wait = retry_after(r, attempt, text)
    if attempt >= 2:
        raise RateLimited("모델 호출 한도 초과", wait)
    return wait


def headers() -> dict:
    return {
        "Authorization": f"Bearer {settings.llm_api_key}",
        "Content-Type": "application/json",
    }


def url() -> str:
    base = (settings.llm_base_url or "https://api.groq.com/openai/v1").rstrip("/")
    return f"{base}/chat/completions"


async def complete(
    messages: list[dict],
    *,
    tools: list[dict] | None = None,
    model: str | None = None,
    temperature: float | None = None,
    max_tokens: int | None = None,
    purpose: str = "tool",
) -> dict:
    body: dict[str, Any] = {
        "model": model or settings.llm_model,
        "messages": messages,
        "temperature": settings.llm_temperature_tool if temperature is None else temperature,
        "max_tokens": max_tokens or settings.llm_max_tokens_tool,
    }
    if tools:
        body["tools"] = tools
        body["tool_choice"] = "auto"
    adapt(body)

    started = time.monotonic()
    for attempt in range(3):
        try:
            r = await upstream.get_client().post(
                url(), headers=headers(), json=body, timeout=settings.llm_timeout
            )
        except httpx.HTTPError as e:
            if attempt < 2:
                await asyncio.sleep([1.0, 3.0][attempt])
                continue
            raise RuntimeError(f"모델 연결 실패: {type(e).__name__}") from e

        elapsed = int((time.monotonic() - started) * 1000)
        if r.status_code == 200:
            payload = r.json()
            count(payload)
            log_call(body["model"], purpose, payload, elapsed)
            choices = payload.get("choices") or []
            if not choices:
                raise Unparsable("모델 응답 choices 없음")
            choice = choices[0]
            msg = choice["message"]
            msg["finish_reason"] = choice.get("finish_reason")
            return msg

        if r.status_code == 429:
            try:
                wait = handle_429(r, r.text, attempt)
            except RateLimited as e:
                log_call(body["model"], purpose, None, elapsed,
                          "daily_limit" if e.daily else "rate_limited")
                raise
            await asyncio.sleep(wait)
            continue

        if r.status_code == 400 and "could not be parsed" in r.text:
            log.warning("도구 호출 파싱 실패 (%d회차) %s", attempt + 1, failed_generation(r))
            if attempt < 2:
                await asyncio.sleep(0.5)
                continue
            raise Unparsable("모델 도구 호출 생성 실패")

        raise RuntimeError(f"LLM {r.status_code}: {r.text[:160]}")

    raise RateLimited("모델 호출 한도 초과")


async def stream(
    messages: list[dict],
    *,
    model: str | None = None,
    temperature: float | None = None,
    max_tokens: int | None = None,
) -> AsyncIterator[str]:
    started = time.monotonic()
    body: dict[str, Any] = {
        "model": model or settings.llm_model,
        "messages": messages,
        "temperature": settings.llm_temperature_compose if temperature is None else temperature,
        "max_tokens": max_tokens or settings.llm_max_tokens_compose,
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    adapt(body)

    for attempt in range(3):
        ctx = upstream.get_client().stream(
            "POST", url(), headers=headers(), json=body,
            timeout=settings.llm_timeout * 2,
        )
        try:
            r = await ctx.__aenter__()
        except httpx.HTTPError as e:
            if attempt < 2:
                await asyncio.sleep([1.0, 3.0][attempt])
                continue
            raise RuntimeError(f"모델 연결 실패: {type(e).__name__}") from e

        try:
            if r.status_code == 200:
                try:
                    async for chunk in read_stream(r):
                        yield chunk
                except httpx.HTTPError as e:
                    raise RuntimeError(f"모델 응답 스트림 끊김: {type(e).__name__}") from e
                return

            text = (await r.aread()).decode("utf-8", "ignore")
            if r.status_code == 429:
                wait = handle_429(r, text, attempt)
                await asyncio.sleep(wait)
                continue

            raise RuntimeError(f"LLM {r.status_code}: {text[:160]}")
        finally:
            await ctx.__aexit__(None, None, None)

    raise RateLimited("모델 호출 한도 초과")


async def read_stream(r: httpx.Response) -> AsyncIterator[str]:
    async for line in r.aiter_lines():
        if not line.startswith("data:"):
            continue
        payload = line[5:].strip()
        if payload == "[DONE]":
            break
        try:
            obj = json.loads(payload)
        except json.JSONDecodeError:
            continue
        if obj.get("usage"):
            count(obj)
            log_call(obj.get("model") or settings.llm_model, "compose", obj, 0)
        choices = obj.get("choices") or []
        if not choices:
            continue
        delta = choices[0].get("delta") or {}
        piece = delta.get("content")
        if piece:
            yield piece


async def healthy() -> bool:
    if not settings.llm_enabled:
        return False
    try:
        await complete(
            [{"role": "user", "content": "ping"}], max_tokens=5, model=settings.llm_model_light
        )
        return True
    except Exception:
        return False
