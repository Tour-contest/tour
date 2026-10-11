from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.core.config import settings

ALGO = "HS256"


def hash_password(raw: str) -> str:
    return bcrypt.hashpw(raw.encode(), bcrypt.gensalt()).decode()


def verify_password(raw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(raw.encode(), hashed.encode())
    except ValueError:
        return False


def now() -> datetime:
    return datetime.now(timezone.utc)


def make_access(user_id: str, role: str) -> str:
    return jwt.encode(
        {
            "sub": user_id,
            "role": role,
            "typ": "access",
            "iat": now(),
            "exp": now() + timedelta(seconds=settings.jwt_access_ttl),
        },
        settings.jwt_secret,
        algorithm=ALGO,
    )


def make_refresh(user_id: str) -> tuple[str, str, datetime]:
    jti = uuid.uuid4().hex
    exp = now() + timedelta(seconds=settings.jwt_refresh_ttl)
    token = jwt.encode(
        {"sub": user_id, "jti": jti, "typ": "refresh", "iat": now(), "exp": exp},
        settings.jwt_secret,
        algorithm=ALGO,
    )
    return token, token_hash(token), exp


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def decode(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[ALGO])
    except jwt.PyJWTError:
        return None
