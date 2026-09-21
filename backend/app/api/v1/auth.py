from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.core.response import EnvelopeRoute
from app.core.config import settings
from app.core.deps import current_user
from app.repository import db
from app.schemas.auth import MeOut, ProvidersOut, TokenOut, WebhookErrorOut
from app.schemas.common import Envelope, OkOut, errors, example
from app.services import auth

router = APIRouter(tags=["auth"], route_class=EnvelopeRoute)
log = logging.getLogger("tour.auth")

_TOKEN_EX = {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1XzBmM2EiLCJ0eXAiOiJhY2Nlc3MifQ.sig",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1XzBmM2EiLCJ0eXAiOiJyZWZyZXNoIn0.sig",
    "expires_in": 3600,
    "user": {"id": "u_0f3a91", "nickname": "널널러", "role": "user", "provider": "kakao"},
}


class OAuthIn(BaseModel):
    code: str | None = Field(None, description="웹. 카카오가 redirect_uri 로 돌려준 인가 코드")
    redirect_uri: str | None = Field(
        None, description="웹. 인가 요청에 쓴 것과 같아야 한다", examples=["https://nullnull.app/"]
    )
    access_token: str | None = Field(
        None, description="앱. 카카오 네이티브 SDK 가 발급한 액세스 토큰"
    )


class LoginIn(BaseModel):
    login_id: str = Field(min_length=2, max_length=40, examples=["admin"])
    password: str = Field(min_length=4, max_length=100, examples=["swordfish"])


class RefreshIn(BaseModel):
    refresh_token: str = Field(description="직전 발급된 리프레시 토큰. 재사용 불가")


class DevIn(BaseModel):
    nickname: str = Field("테스터", description="표시할 닉네임")


@router.post(
    "/auth/oauth/{provider}/callback",
    summary="소셜 로그인",
    responses={200: {"model": Envelope[TokenOut], "description": "로그인 성공",
                     **example(_TOKEN_EX)},
               **errors("401", "422", "429",
                 messages={"401": "카카오 인증에 실패했습니다",
                           "422": "code+redirect_uri 또는 access_token 중 하나가 필요합니다"})},
)
async def oauth_callback(provider: str, body: OAuthIn):
    """카카오 계정으로 로그인한다. provider 는 kakao 만 허용한다.

    미가입 계정은 이 시점에 생성된다. 웹은 code 와 redirect_uri, 앱은 네이티브 SDK 가
    발급한 access_token 을 보낸다.

    앱 경로는 코드 교환이 없으므로 서버가 access_token_info 로 토큰의 발급 앱을 한 번
    더 확인한다. 확인을 생략하면 다른 카카오 앱이 발급한 유효 토큰으로도 로그인된다.
    """
    try:
        if body.access_token:
            return await auth.social_login_token(provider, body.access_token)
        if body.code and body.redirect_uri:
            return await auth.social_login(provider, body.code, body.redirect_uri)
    except ValueError as e:
        raise HTTPException(401, {"code": "OAUTH_FAILED", "message": str(e), "retriable": True})
    raise HTTPException(
        422,
        {"code": "INVALID_REQUEST",
         "message": "code+redirect_uri 또는 access_token 중 하나가 필요합니다"},
    )


@router.post(
    "/auth/dev-login",
    summary="개발용 로그인",
    responses={200: {"model": Envelope[TokenOut], "description": "로그인 성공",
                     **example({**_TOKEN_EX, "user": {"id": "u_dev01", "nickname": "테스터",
                                                        "role": "user", "provider": "dev"}})},
               **errors("403", "422", "429")},
)
async def dev_login(body: DevIn):
    """OAuth 앱 등록 없이 화면을 확인하기 위한 로그인.

    운영 환경에서는 비활성 상태이며 403 이 응답된다. 활성 여부는 /auth/providers 의
    dev_login 으로 확인한다.
    """
    try:
        return await auth.dev_login(body.nickname)
    except ValueError as e:
        raise HTTPException(403, {"code": "FORBIDDEN", "message": str(e)})


@router.post(
    "/auth/login",
    summary="관리자 로그인",
    responses={200: {"model": Envelope[TokenOut], "description": "로그인 성공",
                     **example({**_TOKEN_EX, "user": {"id": "u_admin", "nickname": "관리자",
                                                        "role": "admin", "provider": "local"}})},
               **errors("401", "422", "429",
                 messages={"401": "아이디 또는 비밀번호가 맞지 않습니다"})},
)
async def admin_login(body: LoginIn):
    """관리자 로컬 계정 로그인. 가입 화면과 가입 API 는 없다.

    연속 5회 실패하면 10분간 잠기며, 잠금 중에는 비밀번호가 맞아도 로그인되지 않는다.
    """
    try:
        return await auth.admin_login(body.login_id, body.password)
    except ValueError as e:
        raise HTTPException(401, {"code": "LOGIN_FAILED", "message": str(e)})


@router.post(
    "/auth/refresh",
    summary="토큰 갱신",
    responses={200: {"model": Envelope[TokenOut], "description": "갱신 성공",
                     **example(_TOKEN_EX)},
               **errors("401", "422", "429",
                 messages={"401": "다시 로그인해주세요"})},
)
async def refresh(body: RefreshIn):
    """액세스 토큰 재발급.

    리프레시는 요청마다 새 값으로 교체되므로 응답에 온 값으로 덮어써야 한다. 사용한
    리프레시를 재전송하면 탈취로 간주해 해당 계정의 리프레시를 모두 폐기한다.

    동시에 여러 요청이 갱신을 시도하면 그중 하나가 재사용 판정에 걸린다. 갱신은 한
    번에 하나만 나가야 한다.
    """
    try:
        return await auth.refresh(body.refresh_token)
    except ValueError as e:
        raise HTTPException(401, {"code": "TOKEN_EXPIRED", "message": str(e)})


@router.post(
    "/auth/logout",
    summary="로그아웃",
    responses={200: {"model": Envelope[OkOut], "description": "성공", **example({"ok": True})},
               **errors("401", "429")},
)
async def logout(user: dict = Depends(current_user)):
    """해당 회원의 리프레시를 모두 폐기한다."""
    await auth.logout(user["id"])
    return {"ok": True}


@router.get(
    "/me",
    summary="내 정보 조회",
    responses={200: {"model": Envelope[MeOut], "description": "성공", **example(
        {"id": "u_0f3a91", "nickname": "널널러", "role": "user", "provider": "kakao",
         "created_at": "2026-08-21T14:02:11+09:00"})},
        **errors("401", "403", "429")},
)
async def me(user: dict = Depends(current_user)):
    """토큰 소유자의 계정 정보."""
    return {
        "id": user["id"],
        "nickname": user["nickname"],
        "role": user["role"],
        "provider": user["provider"],
        "email": user.get("email"),
        "created_at": user["created_at"],
    }


@router.delete(
    "/me",
    summary="회원 탈퇴",
    responses={200: {"model": Envelope[OkOut], "description": "탈퇴 완료",
                     **example({"ok": True})},
               **errors("401", "403", "429")},
)
async def withdraw(user: dict = Depends(current_user)):
    """계정, 대화 세션, 대화 이력, 최근 본 관광지를 삭제한다.

    카카오 계정이면 앱 연결도 함께 끊는다. 우리 쪽만 삭제하면 카카오에 연결이 남아
    다시 로그인할 때 같은 회원번호로 새 계정이 생성된다.

    연결 끊기가 실패해도 탈퇴는 진행되며 실패는 서버 로그에 남는다. 클라이언트는 이
    응답을 받은 뒤에 로컬 토큰을 삭제한다.
    """
    if user.get("provider") == "kakao" and user.get("provider_uid"):
        try:
            if not await auth.unlink_kakao(user["provider_uid"]):
                log.warning("카카오 연결 끊기 실패, 탈퇴 진행: user=%s", user["id"])
        except Exception as e:
            log.warning("카카오 연결 끊기 오류, 탈퇴 진행: %s", type(e).__name__)

    await db.delete_user(user["id"])
    return {"ok": True}


@router.post(
    "/auth/kakao/webhook",
    summary="카카오 계정 상태 변경 웹훅",
    status_code=202,
    response_class=Response,
    responses={
        202: {"description": "정상 수신. 본문 없음"},
        400: {"model": WebhookErrorOut, "description": "서명·발급자 검증 실패",
              "content": {"application/json": {"example": {
                  "err": "invalid_key",
                  "description": "서명 또는 발급자 검증에 실패했습니다"}}}},
    },
    openapi_extra={"requestBody": {
        "required": True,
        "content": {"application/secevent+jwt": {
            "schema": {"type": "string", "description": "카카오가 RS256 으로 서명한 SET"},
            "example": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjkxNjZjMSJ9.eyJpc3MiOiJodHRwczovL2thdXRoLmtha2FvLmNvbSJ9.sig",
        }},
    }},
)
async def kakao_webhook(request: Request):
    """카카오가 호출하는 계정 상태 변경 웹훅. SSF 규격이라 공통 응답 형식을 따르지 않는다.

    본문은 카카오가 RS256 으로 서명한 JWT(SET) 다. 공개키(jwks.json)로 검증한 뒤
    user-unlinked 이벤트면 해당 회원번호의 계정을 삭제한다. 사용자가 카카오 계정
    설정에서 연결을 끊거나 카카오 계정을 삭제할 때 호출된다.

    서버가 unlink 를 호출해 끊은 경우에는 웹훅이 오지 않으므로 탈퇴 경로와 중복되지
    않는다. 연결 해제 외의 계정 이벤트는 수신만 하고 202 로 응답한다.

    성공은 202, 검증 실패는 400 이며 3초 안에 응답해야 한다. 카카오 콘솔의
    [앱] > [웹훅] > [계정 상태 변경 웹훅] 에 이 경로를 등록해야 동작한다.
    """
    token = (await request.body()).decode("utf-8", "ignore").strip()
    if not token:
        return JSONResponse(
            status_code=400,
            content={"err": "invalid_request", "description": "본문이 비었습니다"},
        )

    try:
        payload = auth.decode_kakao_event(token)
    except Exception as e:
        log.warning("카카오 웹훅 검증 실패: %s", type(e).__name__)
        return JSONResponse(
            status_code=400,
            content={"err": "invalid_key", "description": "서명 또는 발급자 검증에 실패했습니다"},
        )

    uid = auth.unlinked_uid(payload)
    if uid is None:
        log.info("카카오 웹훅 수신, 미처리 이벤트: %s", list((payload.get("events") or {}).keys()))
        return Response(status_code=202)

    user = await db.find_user(provider="kakao", provider_uid=uid)
    if user is None:
        log.info("카카오 연결 해제 웹훅, 미등록 회원: %s", uid)
        return Response(status_code=202)

    await db.delete_user(user["id"])
    log.info("카카오 연결 해제 웹훅으로 탈퇴 처리: user=%s", user["id"])
    return Response(status_code=202)


@router.get(
    "/auth/providers",
    summary="로그인 수단 조회",
    responses={200: {"model": Envelope[ProvidersOut], "description": "성공", **example(
        {"social": [{"provider": "kakao", "client_id": "a1b2c3d4e5"}],
         "dev_login": False})},
        **errors("429")},
)
async def providers():
    """로그인 화면에 노출할 소셜 제공자와 개발 로그인 활성 여부.

    client_id 는 인가 URL 생성용 공개 식별자다. 카카오 client_id 가 비어 있으면
    social 은 빈 배열이다.
    """
    return {
        "social": [
            {"provider": "kakao", "client_id": settings.kakao_client_id}
        ] if settings.kakao_client_id else [],
        "dev_login": settings.allow_dev_login,
    }
