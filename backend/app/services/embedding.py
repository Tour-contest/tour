from __future__ import annotations

import asyncio

import httpx

from app.core.config import settings
from app.repository import db
from app.services import client, tourapi

MIN_CHARS = 40


async def embed(text: str) -> list[float] | None:
    if not text or len(text) < MIN_CHARS:
        return None
    base = settings.embedding_base_url.rstrip("/")
    try:
        if settings.embedding_provider == "ollama":
            r = await client.get_client().post(
                f"{base}/api/embeddings",
                json={"model": settings.embedding_model, "prompt": text[:2000]},
                timeout=60.0,
            )
            if r.status_code != 200:
                return None
            v = r.json().get("embedding")
        else:
            r = await client.get_client().post(
                f"{base}/embeddings",
                headers={"Authorization": f"Bearer {settings.embedding_api_key}"},
                json={"model": settings.embedding_model, "input": text[:2000]},
                timeout=60.0,
            )
            if r.status_code != 200:
                return None
            data = r.json().get("data") or []
            v = data[0].get("embedding") if data else None
        return v if v else None
    except (httpx.HTTPError, ValueError):
        return None


async def available() -> bool:
    if settings.embedding_provider != "ollama":
        return bool(settings.embedding_api_key)
    try:
        r = await client.get_client().get(
            f"{settings.embedding_base_url.rstrip('/')}/api/tags", timeout=5.0
        )
        if r.status_code != 200:
            return False
        names = [m.get("name") for m in r.json().get("models", [])]
        return settings.embedding_model in names
    except httpx.HTTPError:
        return False


async def build_for_area(crowd_cd: str, tour_cd: str, limit: int = 60) -> dict:
    if not await available():
        return {"status": "unavailable", "built": 0}

    mapping = await db.get_mapping(crowd_cd)
    targets = [
        (v["content_id"], name)
        for name, v in mapping.items()
        if v.get("content_id")
    ]
    have = await db.vector_ids([t[0] for t in targets])
    todo = [t for t in targets if t[0] not in have][:limit]
    if not todo:
        return {"status": "ok", "built": 0, "total": len(targets)}

    sem = asyncio.Semaphore(3)

    async def one(content_id: str, name: str):
        async with sem:
            try:
                d = await tourapi.detail_common(content_id)
            except Exception:
                return None
            if not d:
                return None
            text = f"{d.get('title', '')}. {d.get('overview', '')}"
            vec = await embed(text)
            if not vec:
                return None
            return {
                "content_id": content_id,
                "title": d.get("title"),
                "lcls1": d.get("lcls1", ""),
                "lcls2": d.get("lcls2", ""),
                "signgu_cd": crowd_cd,
                "embedding": vec,
            }

    rows = [r for r in await asyncio.gather(*[one(c, n) for c, n in todo]) if r]
    await db.put_vectors(rows)
    return {"status": "ok", "built": len(rows), "total": len(targets)}


async def similar(
    content_id: str, crowd_cd: str, *, limit: int = 10, exclude: set[str] | None = None,
    min_similarity: float | None = None,
) -> list[dict]:
    floor = settings.similarity_min if min_similarity is None else min_similarity
    return await db.similar_vectors(
        content_id, crowd_cd, limit=limit, min_similarity=floor, exclude=exclude,
    )
