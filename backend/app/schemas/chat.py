from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.common import CursorPage, OffsetPage


class SessionItem(BaseModel):
    id: str = Field(description="세션 식별자. 다음 메시지에 그대로 실어 보낸다",
                    examples=["a1b2c3d4e5f6"])
    title: str | None = Field(None, description="첫 메시지로 만들어진다", examples=["태안 한적한 캠핑장"])
    messages: int = Field(description="메시지 수", examples=[4])
    last_active_at: str | None = Field(None, description="목록 정렬 기준",
                                       examples=["2026-09-06T09:11:40+09:00"])


class SessionsOut(BaseModel):
    items: list[SessionItem] = Field(description="최근 활동 순")
    page: OffsetPage


class MessageItem(BaseModel):
    id: int = Field(description="이력 커서로 쓰는 값", examples=[8822])
    session_id: str = Field(examples=["a1b2c3d4e5f6"])
    role: str = Field(description="user 또는 assistant", examples=["assistant"])
    content: str = Field(examples=["태안에서 지금 한적한 야영장 세 곳을 추렸어요."])
    tool_trace: list[dict] = Field(default_factory=list,
                                   description="그 답변에 그린 카드 목록(type, payload). 화면 복원용")
    created_at: str | None = Field(None, examples=["2026-09-06T08:40:31+09:00"])


class MessagesOut(BaseModel):
    items: list[MessageItem] = Field(description="오래된 것부터")
    page: CursorPage
