from __future__ import annotations

from typing import Any, Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")

TS_EXAMPLE = "2026-09-06T09:12:03+09:00"


class Envelope(BaseModel, Generic[T]):
    """모든 응답의 공통 형식."""

    success: bool = Field(True, description="요청이 처리됐는지. 데이터가 있는지는 data.status 로 본다")
    code: str = Field("OK", description="성공은 OK, 실패는 오류 코드")
    message: str | None = Field(None, description="사용자에게 그대로 보여줄 수 있는 문장. 성공이면 null")
    data: T | None = Field(None, description="실제 내용")
    retriable: bool = Field(False, description="다시 눌러볼 만한 오류인지. 재시도 버튼 노출 판단용")
    timestamp: str = Field(TS_EXAMPLE, description="응답 시각 (KST)")


class ErrorOut(BaseModel):
    """실패 응답. data 는 항상 null 이다."""

    success: bool = Field(False)
    code: str = Field(description="오류 코드. 화면 분기는 이걸로 한다")
    message: str = Field(description="사용자에게 그대로 보여줄 수 있는 문장")
    data: None = None
    retriable: bool = Field(False, description="재시도 버튼을 줄지 판단")
    timestamp: str = Field(TS_EXAMPLE)


class OkOut(BaseModel):
    """더 돌려줄 게 없는 처리 결과."""

    ok: bool = True


class OffsetPage(BaseModel):
    """offset 페이징 정보."""

    limit: int = Field(description="한 번에 받은 개수", examples=[30])
    offset: int = Field(description="건너뛴 개수", examples=[0])
    total: int = Field(description="전체 건수", examples=[41])
    has_more: bool = Field(description="true 면 offset 을 밀어서 더 부른다")


class CursorPage(BaseModel):
    """커서 페이징 정보. 보는 동안에도 늘어나는 목록에 쓴다."""

    limit: int = Field(description="한 번에 받은 개수", examples=[100])
    has_more: bool = Field(description="true 면 앞쪽에 더 있다")
    next_before: int | None = Field(
        None, description="다음 요청의 before 에 그대로 넣으면 이어서 받는다", examples=[8821]
    )


def e(code: str, message: str, retriable: bool = False) -> dict:
    return {"success": False, "code": code, "message": message,
            "data": None, "retriable": retriable, "timestamp": TS_EXAMPLE}


_ERRORS: dict[str, dict[str, Any]] = {
    "401": {"description": "토큰이 없거나 만료됨",
            "example": e("UNAUTHORIZED", "로그인이 필요합니다")},
    "403": {"description": "권한 없음 · 정지된 계정",
            "example": e("FORBIDDEN", "권한이 없습니다")},
    "404": {"description": "대상을 찾지 못함",
            "example": e("NOT_FOUND", "관광지를 찾을 수 없습니다")},
    "422": {"description": "입력값이 규격에 안 맞음",
            "example": e("INVALID_INPUT", "limit 값을 확인해주세요")},
    "429": {"description": "호출 한도 초과. Retry-After 만큼 기다렸다 다시",
            "example": e("RATE_LIMITED", "요청이 너무 많아요. 잠시 후 다시 시도해주세요", True)},
    "502": {"description": "공공데이터 응답이 이상하거나 실패",
            "example": e("UPSTREAM_ERROR", "관광 정보를 가져오지 못했어요", True)},
    "503": {"description": "공공데이터 일일 한도 소진. 오늘은 더 못 부름 (재시도 버튼 금지)",
            "example": e("UPSTREAM_QUOTA_EXCEEDED",
                          "조회 한도를 오늘 다 썼어요. 내일 다시 시도해주세요.")},
}


def errors(*codes: str, messages: dict[str, str] | None = None) -> dict[int | str, dict[str, Any]]:
    out: dict[int | str, dict[str, Any]] = {}
    for c in codes:
        spec = _ERRORS[c]
        example = dict(spec["example"])
        if messages and c in messages:
            example["message"] = messages[c]
        out[int(c)] = {
            "model": ErrorOut,
            "description": spec["description"],
            "content": {"application/json": {"example": example}},
        }
    return out


def example(payload: Any) -> dict:
    return {"content": {"application/json": {"example": {
        "success": True, "code": "OK", "message": None,
        "data": payload, "retriable": False, "timestamp": TS_EXAMPLE}}}}


class Loose(BaseModel):
    """상류 응답을 그대로 흘려보내는 스키마의 부모.

    관광정보는 관광지 종류마다 내려오는 필드가 다르다. 여기 적힌 것만 오는 게 아니라
    적힌 건 대체로 온다는 뜻이라, 모르는 키가 있어도 문서와 어긋난 게 아니다.
    """

    model_config = ConfigDict(extra="allow")
