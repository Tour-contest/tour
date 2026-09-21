from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import httpx
import jwt

from app.core import security
from app.core.config import settings
from app.repository import db
from app.services import client

LOCK_AFTER = 5
LOCK_MINUTES = 10

PROVIDER = "kakao"
TOKEN_URL = "https://kauth.kakao.com/oauth/token"
PROFILE_URL = "https://kapi.kakao.com/v2/user/me"
TOKEN_INFO_URL = "https://kapi.kakao.com/v1/user/access_token_info"


def check_provider(provider: str) -> None:
    if provider != PROVIDER:
        raise ValueError("지원하지 않는 로그인 방식입니다")


async def exchange(code: str, redirect_uri: str) -> dict:
    if not settings.kakao_client_id:
        raise ValueError("카카오 클라이언트 정보가 설정되지 않았습니다")

    body = {
        "grant_type": "authorization_code",
        "client_id": settings.kakao_client_id,
        "code": code,
        "redirect_uri": redirect_uri,
    }
    if settings.kakao_client_secret:
        body["client_secret"] = settings.kakao_client_secret
    r = await client.get_client().post(TOKEN_URL, data=body, timeout=15.0)
    if r.status_code != 200:
        raise ValueError("제공자 인증에 실패했습니다. 다시 시도해주세요")
    return r.json()


async def profile(access_token: str) -> tuple[str, str, str | None]:
    r = await client.get_client().get(
        PROFILE_URL, headers={"Authorization": f"Bearer {access_token}"}, timeout=15.0
    )
    if r.status_code != 200:
        raise ValueError("제공자 정보를 가져오지 못했습니다")
    d = r.json()

    uid = d.get("id")
    if not uid:
        raise ValueError("제공자 정보를 가져오지 못했습니다")
    email = (d.get("kakao_account") or {}).get("email")
    return str(uid), (d.get("properties") or {}).get("nickname") or "여행자", email


async def social_login(provider: str, code: str, redirect_uri: str) -> dict:
    check_provider(provider)
    token = await exchange(code, redirect_uri)
    uid, name, email = await profile(token.get("access_token", ""))
    return await issue_for_social(provider, uid, name, email)


async def check_kakao_audience(access_token: str) -> None:
    if not settings.kakao_app_id:
        return
    r = await client.get_client().get(
        TOKEN_INFO_URL,
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=15.0,
    )
    if r.status_code != 200 or str(r.json().get("app_id")) != settings.kakao_app_id:
        raise ValueError("제공자 인증에 실패했습니다. 다시 시도해주세요")


async def social_login_token(provider: str, access_token: str) -> dict:
    check_provider(provider)
    if not access_token:
        raise ValueError("제공자 인증에 실패했습니다. 다시 시도해주세요")

    await check_kakao_audience(access_token)
    uid, name, email = await profile(access_token)
    return await issue_for_social(provider, uid, name, email)


async def issue_for_social(provider: str, uid: str, name: str,
                           email: str | None = None) -> dict:
    user = await db.find_user(provider=provider, provider_uid=uid)
    if user is None:
        user = await db.create_user(
            {
                "id": uuid.uuid4().hex,
                "provider": provider,
                "provider_uid": uid,
                "nickname": name,
                "email": email,
                "role": "user",
            }
        )
    elif email and user.get("email") != email:
        await db.set_user_email(user["id"], email)
        user["email"] = email
    if user["status"] != "active":
        raise ValueError("이용이 정지된 계정입니다")

    await db.touch_login(user["id"], ok=True)
    return await issue(user)


async def dev_login(nickname: str = "테스터") -> dict:
    if not settings.allow_dev_login:
        raise ValueError("사용할 수 없는 로그인 방식입니다")
    return await issue_for_social("dev", f"dev-{nickname}", nickname)


async def admin_login(login_id: str, password: str) -> dict:
    user = await db.find_user(login_id=login_id)
    if user is None:
        raise ValueError("아이디 또는 비밀번호가 맞지 않습니다")

    if user["locked_until"]:
        until = datetime.fromisoformat(user["locked_until"])
        if until > datetime.now(timezone.utc):
            raise ValueError("로그인 시도가 많아 잠시 잠겼습니다. 잠시 후 다시 시도해주세요")

    if not security.verify_password(password, user["password_hash"] or ""):
        fails = user["fail_count"] + 1
        lock = None
        if fails >= LOCK_AFTER:
            lock = (datetime.now(timezone.utc) + timedelta(minutes=LOCK_MINUTES)).isoformat()
        await db.touch_login(user["id"], ok=False, lock_until=lock)
        raise ValueError("아이디 또는 비밀번호가 맞지 않습니다")

    if user["status"] != "active":
        raise ValueError("이용이 정지된 계정입니다")

    await db.touch_login(user["id"], ok=True)
    return await issue(user)


async def issue(user: dict) -> dict:
    access = security.make_access(user["id"], user["role"])
    refresh, hashed, exp = security.make_refresh(user["id"])
    await db.save_refresh(hashed, user["id"], exp.isoformat())
    return {
        "access_token": access,
        "refresh_token": refresh,
        "expires_in": settings.jwt_access_ttl,
        "user": {
            "id": user["id"],
            "nickname": user["nickname"],
            "role": user["role"],
            "provider": user["provider"],
        },
    }


async def refresh(token: str) -> dict:
    payload = security.decode(token)
    if not payload or payload.get("typ") != "refresh":
        raise ValueError("다시 로그인해주세요")

    hashed = security.token_hash(token)
    row = await db.get_refresh(hashed)
    if row is None:
        raise ValueError("다시 로그인해주세요")

    if not await db.revoke_refresh(hashed):
        await db.revoke_all_refresh(row["user_id"])
        raise ValueError("보안을 위해 로그아웃되었습니다. 다시 로그인해주세요")

    user = await db.find_user(id=row["user_id"])
    if user is None or user["status"] != "active":
        raise ValueError("다시 로그인해주세요")
    return await issue(user)


async def logout(user_id: str) -> None:
    await db.revoke_all_refresh(user_id)


async def unlink_kakao(uid: str) -> bool:
    if not settings.kakao_admin_key or not uid:
        return False
    r = await client.get_client().post(
        "https://kapi.kakao.com/v1/user/unlink",
        headers={
            "Authorization": f"KakaoAK {settings.kakao_admin_key}",
            "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
        },
        data={"target_id_type": "user_id", "target_id": uid},
        timeout=10.0,
    )
    return r.status_code == 200


KAKAO_ISSUER = "https://kauth.kakao.com"
KAKAO_JWKS_URL = "https://kauth.kakao.com/.well-known/jwks.json"
EVENT_USER_UNLINKED = "https://schemas.openid.net/secevent/oauth/event-type/user-unlinked"

_jwk_client: jwt.PyJWKClient | None = None


def jwks() -> jwt.PyJWKClient:
    global _jwk_client
    if _jwk_client is None:
        _jwk_client = jwt.PyJWKClient(KAKAO_JWKS_URL, cache_keys=True)
    return _jwk_client


def decode_kakao_event(token: str) -> dict:
    if not settings.kakao_client_id:
        raise ValueError("kakao_client_id 없음, 웹훅 검증 불가")
    key = jwks().get_signing_key_from_jwt(token).key
    return jwt.decode(
        token,
        key,
        algorithms=["RS256"],
        audience=settings.kakao_client_id,
        issuer=KAKAO_ISSUER,
    )


def unlinked_uid(payload: dict) -> str | None:
    events = payload.get("events") or {}
    ev = events.get(EVENT_USER_UNLINKED)
    if ev is None:
        return None
    subject = (ev or {}).get("subject") or {}
    uid = subject.get("sub") or payload.get("sub")
    return str(uid) if uid else None


async def ensure_admin() -> None:
    if not settings.admin_login_id or not settings.admin_password:
        return
    if await db.find_user(login_id=settings.admin_login_id):
        return
    await db.create_user(
        {
            "id": uuid.uuid4().hex,
            "provider": "local",
            "login_id": settings.admin_login_id,
            "password_hash": security.hash_password(settings.admin_password),
            "nickname": "관리자",
            "role": "admin",
        }
    )
