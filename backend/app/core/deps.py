from __future__ import annotations

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core import security
from app.repository import db

bearer = HTTPBearer(
    auto_error=False,
    description="로그인 응답의 access_token. 만료되면 401 TOKEN_EXPIRED 가 온다",
)


async def current_user(cred: HTTPAuthorizationCredentials | None = Depends(bearer)) -> dict:
    tok = cred.credentials.strip() if cred else None
    if not tok:
        raise HTTPException(401, {"code": "UNAUTHORIZED", "message": "로그인이 필요합니다"})
    payload = security.decode(tok)
    if not payload or payload.get("typ") != "access":
        raise HTTPException(
            401, {"code": "TOKEN_EXPIRED", "message": "다시 로그인해주세요", "retriable": True}
        )
    user = await db.find_user(id=payload["sub"])
    if user is None or user["status"] != "active":
        raise HTTPException(403, {"code": "FORBIDDEN", "message": "이용할 수 없는 계정입니다"})
    return user


async def admin_user(user: dict = Depends(current_user)) -> dict:
    if user["role"] != "admin":
        raise HTTPException(403, {"code": "FORBIDDEN", "message": "권한이 없습니다"})
    return user
