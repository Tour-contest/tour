from __future__ import annotations

from pydantic import BaseModel, Field

ACCESS = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1XzBmM2EiLCJ0eXAiOiJhY2Nlc3MifQ.sig"
REFRESH = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1XzBmM2EiLCJ0eXAiOiJyZWZyZXNoIn0.sig"


class UserOut(BaseModel):
    id: str = Field(description="내부 회원 식별자", examples=["u_0f3a91"])
    nickname: str | None = Field(None, description="제공자에서 받은 이름", examples=["널널러"])
    role: str = Field(description="user 또는 admin", examples=["user"])
    provider: str = Field(description="kakao · local(관리자) · dev(개발 로그인)", examples=["kakao"])


class TokenOut(BaseModel):
    access_token: str = Field(description="Authorization: Bearer 로 보낸다", examples=[ACCESS])
    refresh_token: str = Field(
        description="갱신용. 쓸 때마다 회전하므로 응답에 온 새 값으로 덮어써야 한다", examples=[REFRESH]
    )
    expires_in: int = Field(description="access 유효 시간(초)", examples=[3600])
    user: UserOut


class MeOut(BaseModel):
    id: str = Field(examples=["u_0f3a91"])
    nickname: str | None = Field(None, examples=["널널러"])
    role: str = Field(examples=["user"])
    provider: str = Field(examples=["kakao"])
    email: str | None = Field(None, description="카카오 이메일 동의 시에만 값이 있다",
                              examples=["nullnull@kakao.com"])
    created_at: str | None = Field(None, description="가입 시각", examples=["2026-08-21T14:02:11+09:00"])


class ProviderOut(BaseModel):
    provider: str = Field(description="지금은 kakao 뿐이다", examples=["kakao"])
    client_id: str = Field(
        description="인가 URL 을 만드는 공개 식별자. 비밀이 아니라 내려줘도 된다",
        examples=["a1b2c3d4e5"],
    )


class ProvidersOut(BaseModel):
    social: list[ProviderOut] = Field(description="버튼을 그릴 소셜 제공자. 클라이언트에 박지 말 것")
    dev_login: bool = Field(description="false 면 개발 로그인 버튼을 아예 만들지 않는다")


class WebhookErrorOut(BaseModel):
    """카카오가 정한 형식. 공통 응답 형식을 따르지 않는다."""

    err: str = Field(examples=["invalid_key"])
    description: str = Field(examples=["서명 또는 발급자 검증에 실패했습니다"])
