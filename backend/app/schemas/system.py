from __future__ import annotations

from pydantic import BaseModel, Field


class HealthOut(BaseModel):
    ok: bool = Field(True, description="프로세스가 살아 있으면 항상 true")


class ReadyOut(BaseModel):
    ok: bool = Field(description="지역코드가 하나라도 적재됐는지")
    areas_loaded: int = Field(description="적재된 시군구 수", examples=[268])
    llm_enabled: bool = Field(description="false 면 대화가 규칙 기반으로 돈다. 응답 형태는 같다")
    llm_model: str | None = Field(None, description="쓰는 모델. llm_enabled 가 false 면 null",
                                  examples=["gpt-4o-mini"])
    embedding_ready: bool = Field(description="false 면 유사 관광지가 빈 상태로 나간다")
    service_key_set: bool = Field(description="공공데이터 서비스키가 설정됐는지")


class AttributionOut(BaseModel):
    text: str = Field(description="화면에 그대로 붙이는 문구", examples=["출처: ⓒ한국관광공사"])
    note: str = Field(description="지켜야 하는 제약")


class RootOut(BaseModel):
    name: str = Field(examples=["널널 API"])
    docs: str = Field(examples=["/docs"])
    openapi: str = Field(examples=["/openapi.json"])
