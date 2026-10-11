from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.common import OffsetPage


class QuotaOut(BaseModel):
    limit: int = Field(description="일일 상한", examples=[100000])
    used_today: int = Field(examples=[1469])
    remaining: int = Field(examples=[98531])


class DailyCount(BaseModel):
    date: str = Field(examples=["2026-09-05"])
    count: int = Field(examples=[24])


class DailyCalls(BaseModel):
    date: str = Field(examples=["2026-09-05"])
    real: int = Field(description="상류에 실제로 나간 호출 수", examples=[2210])
    cached: int = Field(description="요청 내 중복 제거로 아낀 호출 수", examples=[310])


class CallLogItem(BaseModel):
    id: int = Field(examples=[48211])
    session_id: str | None = Field(None, description="대화에서 나간 호출이면 세션 id")
    provider: str = Field(description="data.go.kr 또는 naver", examples=["data.go.kr"])
    operation: str = Field(examples=["KorService2/detailCommon2"])
    params: str | None = Field(None, description="요청 파라미터. serviceKey 는 마스킹된다")
    status_code: int | None = Field(None, examples=[200])
    result_code: str | None = Field(None, examples=["0000"])
    latency_ms: int | None = Field(None, examples=[262])
    cache_hit: int = Field(description="1 이면 상류를 부르지 않고 캐시로 답한 것", examples=[0])
    called_at: str = Field(examples=["2026-09-06T09:11:02+09:00"])


class LlmUsage(BaseModel):
    calls: int = Field(examples=[96])
    prompt: int = Field(description="입력 토큰 합", examples=[184220])
    completion: int = Field(description="출력 토큰 합", examples=[20114])
    since: str = Field(description="메모리 카운터라 재시작하면 0 부터 다시 센다",
                       examples=["서버 시작 후"])


class ApiCallsOut(BaseModel):
    date: str = Field(description="집계 시간대(KST) 기준 날짜", examples=["2026-09-06"])
    quota: QuotaOut
    by_operation: dict[str, int] = Field(description="오퍼레이션별 호출 수",
                                         examples=[{"KorService2/detailCommon2": 812}])
    error_rate: float = Field(description="0~1 비율", examples=[0.004])
    avg_latency_ms: int = Field(examples=[318])
    cache_hits: int = Field(examples=[260])
    cache_rate: float = Field(description="0~1 비율", examples=[0.15])
    cache_enabled: bool = Field(
        description="요청 안의 중복 호출을 없애는 캐시. 심사 시연 때 꺼야 해서 노출한다"
    )
    daily: list[DailyCalls] = Field(description="최근 7일")
    llm: LlmUsage
    recent: list[CallLogItem]


class LlmPrice(BaseModel):
    in_: float = Field(alias="in", description="입력 100만 토큰당 달러", examples=[0.075])
    out: float = Field(description="출력 100만 토큰당 달러", examples=[0.3])


class LlmDaily(BaseModel):
    date: str = Field(examples=["2026-09-05"])
    prompt: int = Field(examples=[220110])
    completion: int = Field(examples=[26400])
    calls: int = Field(examples=[112])
    cost_usd: float = Field(examples=[0.0244])


class LlmPurpose(BaseModel):
    purpose: str = Field(description="tool · optimize · compose · summary", examples=["tool"])
    calls: int = Field(examples=[60])
    tokens: int = Field(description="입력+출력 합", examples=[150200])


class LlmMetricsOut(BaseModel):
    date: str = Field(examples=["2026-09-06"])
    model: str = Field(examples=["gpt-4o-mini"])
    price_per_1m: LlmPrice
    calls: int = Field(examples=[96])
    prompt_tokens: int = Field(examples=[184220])
    completion_tokens: int = Field(examples=[20114])
    avg_latency_ms: int = Field(description="성공 호출 평균", examples=[2140])
    rate_limited: int = Field(description="분당 제한에 걸린 호출 수", examples=[2])
    errors: int = Field(examples=[0])
    by_purpose: list[LlmPurpose]
    cost_today_usd: float = Field(description="단가 환산값. 단가를 바꾸면 과거치도 같이 바뀐다",
                                  examples=[0.0198])
    daily: list[LlmDaily]


class TopAttraction(BaseModel):
    title: str = Field(examples=["꽃지해수욕장"])
    count: int = Field(examples=[12])


class ChatStatsOut(BaseModel):
    daily: list[DailyCount] = Field(description="일자별 질문 수. 최근 14일")
    sessions: int = Field(examples=[41])
    users: int = Field(examples=[10])
    top_attractions: list[TopAttraction] = Field(description="많이 조회된 관광지 상위 10")


class MappingStatsOut(BaseModel):
    total: int = Field(description="혼잡도에서 받은 이름 수", examples=[8718])
    matched: int = Field(description="그중 content_id 를 찾은 수. 낮으면 상세로 못 넘어간다",
                         examples=[7316])
    areas: int = Field(examples=[256])


class VectorStatsOut(BaseModel):
    vectors: int = Field(examples=[3632])
    areas: int = Field(examples=[254])
    available: bool = Field(description="false 면 임베딩 제공자가 안 붙어 유사 관광지가 빈다")


class AdminUserItem(BaseModel):
    id: str = Field(examples=["u_0f3a91"])
    provider: str = Field(examples=["kakao"])
    provider_uid: str | None = Field(None, description="제공자 쪽 회원번호", examples=["3812004421"])
    login_id: str | None = Field(None, description="관리자 계정만 있다")
    nickname: str | None = Field(None, examples=["널널러"])
    role: str = Field(examples=["user"])
    status: str = Field(description="active · suspended", examples=["active"])
    fail_count: int | None = Field(None, description="로그인 연속 실패 횟수")
    locked_until: str | None = Field(None, description="잠긴 계정의 해제 시각")
    created_at: str | None = Field(None, examples=["2026-08-21T14:02:11+09:00"])
    last_login_at: str | None = Field(None, examples=["2026-09-06T08:39:50+09:00"])


class UsersOut(BaseModel):
    items: list[AdminUserItem]
    page: OffsetPage


class LoadAreaCodesOut(BaseModel):
    categories: int = Field(description="분류체계 코드 수", examples=[4])
    tour: int = Field(description="관광정보 쪽 지역 수", examples=[258])
    crowd: int = Field(description="혼잡도 쪽 지역 수", examples=[268])
    saved: int = Field(description="저장한 시군구 수", examples=[268])
    code_differs: int = Field(description="두 체계의 코드가 다른 곳 수", examples=[12])
    tour_unmatched: list[str] = Field(description="관광 쪽에서 짝을 못 찾은 이름")


class BuildVectorsOut(BaseModel):
    status: str = Field(description="ok, 또는 임베딩 제공자 미연결이면 unavailable", examples=["ok"])
    built: int = Field(description="새로 만든 벡터 수", examples=[54])
    total: int | None = Field(None, description="대상 관광지 수. 소개문이 짧은 곳은 생성에서 빠진다",
                              examples=[60])
    signgu_nm: str | None = Field(None, examples=["태안군"])
