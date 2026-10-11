from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.common import Loose


class AttractionItem(Loose):
    content_id: str = Field(description="관광정보 식별자. 상세·혼잡도 조회의 키", examples=["126165"])
    title: str = Field(examples=["꽃지해수욕장"])
    addr1: str | None = Field(None, examples=["충남 태안군 안면읍 꽃지해안로"])
    content_type_id: str | None = Field(None, description="관광타입. 12=관광지, 28=레포츠 …",
                                        examples=["12"])
    tour_cd: str | None = Field(None, examples=["34_14"])
    signgu_cd: str | None = Field(None, examples=["44825"])
    signgu_nm: str | None = Field(None, examples=["태안군"])
    image: str | None = Field(None, description="대표 이미지. 없으면 빈 문자열")
    mapx: str | None = Field(None, description="경도", examples=["126.3312"])
    mapy: str | None = Field(None, description="위도", examples=["36.5024"])


class SearchOut(BaseModel):
    status: str = Field(description="ok · not_found · no_data", examples=["ok"])
    confident: bool | None = Field(
        None, description="true 면 한 곳으로 확정된 것이라 items[0] 으로 바로 상세에 가도 된다"
    )
    items: list[AttractionItem] = Field(default_factory=list)
    hint: str | None = Field(None, description="not_found 일 때 다시 물어볼 문구")
    message: str | None = Field(None, description="검색 한도만 소진됐을 때의 안내")
    source: str | None = Field(None, examples=["출처: ⓒ한국관광공사"])


class InfoItem(BaseModel):
    name: str = Field(examples=["이용시간"])
    value: str = Field(examples=["상시"])


class DetailOut(Loose):
    """관광지 종류마다 내려오는 필드가 다르다. 여기 적힌 건 대체로 오는 것들이다."""

    status: str = Field(description="ok · not_found · quota_exceeded", examples=["ok"])
    content_id: str | None = Field(None, examples=["126165"])
    title: str | None = Field(None, examples=["꽃지해수욕장"])
    addr1: str | None = Field(None, examples=["충남 태안군 안면읍 꽃지해안로 293-4"])
    tel: str | None = Field(None, examples=["041-670-2691"])
    overview: str | None = Field(None, description="소개문. 유사도 벡터도 이걸로 만든다")
    content_type_id: str | None = Field(None, examples=["12"])
    signgu_cd: str | None = Field(None, examples=["44825"])
    signgu_nm: str | None = Field(None, examples=["태안군"])
    sido_nm: str | None = Field(None, examples=["충청남도"])
    image: str | None = None
    info: list[InfoItem] = Field(default_factory=list, description="이용시간·주차 같은 항목")
    pet: list[dict] = Field(default_factory=list, description="대화 경로에서만 채운다. 화면은 /pet 을 따로 부른다")
    source: str | None = None


class CrowdPoint(BaseModel):
    date: str = Field(examples=["2026-09-06"])
    weekday: str = Field(description="요일 한 글자. 그래프 x축 라벨로 쓴다", examples=["일"])
    rate: float = Field(description="집중률. % 를 붙이지 않는다", examples=[41.2])
    level: str = Field(description="혼잡 · 보통 · 한적 세 단어만 쓴다", examples=["한적"])


class CrowdSummary(BaseModel):
    peak_date: str = Field(examples=["2026-09-08"])
    peak_rate: float = Field(examples=[82.4])
    min_date: str = Field(examples=["2026-09-06"])
    min_rate: float = Field(examples=[41.2])
    avg: float = Field(examples=[60.8])


class CrowdOut(BaseModel):
    status: str = Field(description="ok · not_found · quota_exceeded", examples=["ok"])
    content_id: str | None = Field(None, examples=["126165"])
    has_data: bool = Field(description="false 면 이 관광지의 집중률이 없다. message 를 그대로 보여준다")
    matched_name: str | None = Field(None, description="혼잡도 쪽에서 매칭된 관광지명",
                                     examples=["꽃지해수욕장"])
    match_method: str | None = Field(None, description="exact · keyword · reverse. exact 가 아니면 화면에 안내",
                                     examples=["exact"])
    match_confidence: float | None = Field(None, examples=[1.0])
    series: list[CrowdPoint] = Field(default_factory=list, description="날짜 순 예측값")
    summary: CrowdSummary | None = None
    available_days: int | None = Field(None, description="이 관광지에 있는 예측 일수. 기간 토글 상한",
                                       examples=[28])
    signgu_cd: str | None = Field(None, examples=["44825"])
    signgu_nm: str | None = Field(None, examples=["태안군"])
    message: str | None = None
    source: str | None = None


class AltReason(BaseModel):
    lower_by: float | None = Field(None, description="기준 관광지보다 낮은 집중률 차. 퍼센트가 아니다",
                                   examples=[52.5])
    same_category: bool | None = Field(None, description="기준 관광지와 분류체계 대분류가 같은지")
    distance_km: float | None = Field(None, description="기준 관광지와의 거리(km)", examples=[7.4])
    similarity: float | None = Field(
        None, description="소개문 유사도. 절대값 분포가 모델마다 달라 순서용으로 본다", examples=[0.545]
    )


class AltItem(Loose):
    content_id: str | None = Field(None, examples=["126266"])
    name: str = Field(examples=["운여해변"])
    rate: float = Field(examples=[28.4])
    level: str = Field(examples=["한적"])
    date: str | None = Field(None, description="비교 기준일", examples=["2026-09-06"])
    image: str | None = None
    addr1: str | None = Field(None, examples=["충남 태안군 안면읍"])
    reason: AltReason | None = None


class AltBase(BaseModel):
    name: str | None = Field(None, examples=["꽃지해수욕장"])
    rate: float | None = Field(None, examples=[88.0])
    level: str | None = Field(None, examples=["혼잡"])


class AlternativesOut(BaseModel):
    status: str = Field(description="ok · no_data · not_found", examples=["ok"])
    base: AltBase | None = Field(None, description="기준이 된 관광지")
    items: list[AltItem] = Field(default_factory=list,
                                 description="서버가 확정한 순서다. 다시 정렬하지 말 것")
    sort_basis: str | None = Field(None, description="crowding 또는 none", examples=["crowding"])
    relaxed: bool | None = Field(None, description="조건을 못 맞춰 범위를 넓혔는지")
    candidate_source: str | None = Field(
        None,
        description="related: 연관 관광지에서, area: 지역 전체에서, related+area: 둘을 합쳐 골랐다",
        examples=["related"],
    )
    signgu_nm: str | None = Field(None, examples=["태안군"])
    source: str | None = None


class TrendItem(BaseModel):
    name: str = Field(description="조회에 쓴 짧은 이름", examples=["꽃지"])
    display_name: str | None = Field(None, description="화면에 쓸 원래 이름", examples=["꽃지해수욕장"])
    trend: str = Field(description="rising · falling · flat", examples=["falling"])
    change_pct: float | None = Field(None, description="최근 4주 기울기(%)", examples=[-23.5])
    weeks: int = Field(description="집계에 쓰인 주 수", examples=[8])


class InterestOut(BaseModel):
    status: str = Field(description="ok · no_data · upstream_error", examples=["ok"])
    items: list[TrendItem] = Field(default_factory=list)


class ImageItem(BaseModel):
    url: str = Field(description="원본 이미지 주소")
    small: str | None = Field(None, description="썸네일. 없으면 원본과 같다")
    name: str | None = Field(None, examples=["꽃지해수욕장"])
    copyright: str | None = Field(None, description="공공누리 유형 표기 문구. 화면에 그대로 쓴다",
                                  examples=["공공누리 제1유형 (출처표시)"])


class ImagesOut(BaseModel):
    status: str = Field(description="ok · no_data · quota_exceeded", examples=["ok"])
    items: list[ImageItem] = Field(default_factory=list)
    message: str | None = None
    source: str | None = None


class PetOut(BaseModel):
    status: str = Field(description="ok · no_data · quota_exceeded. no_data 가 정상인 곳이 많다",
                        examples=["no_data"])
    items: list[dict] = Field(default_factory=list)
    message: str | None = None
    source: str | None = None


class SimilarItem(BaseModel):
    content_id: str = Field(examples=["126266"])
    title: str | None = Field(None, examples=["운여해변"])
    lcls1: str | None = Field(None, description="분류체계 대분류", examples=["NA"])
    lcls2: str | None = Field(None, description="분류체계 중분류", examples=["NA01"])
    similarity: float = Field(
        description="코사인 유사도. 임베딩 모델마다 분포가 달라 순서로 쓰는 게 맞다", examples=[0.545]
    )


class SimilarOut(BaseModel):
    status: str = Field(description="ok · no_data · not_found · quota_exceeded", examples=["ok"])
    items: list[SimilarItem] = Field(default_factory=list)
    message: str | None = None
    source: str | None = None


class RecentItem(BaseModel):
    content_id: str = Field(examples=["126165"])
    title: str = Field(examples=["꽃지해수욕장"])
    signgu_cd: str | None = Field(None, examples=["44825"])
    signgu_nm: str | None = Field(None, examples=["태안군"])
    last_level: str | None = Field(
        None, description="기록한 시점의 등급이다. 지금 값이 아니니 참고용으로만", examples=["혼잡"]
    )
    viewed_at: str | None = Field(None, examples=["2026-09-06T09:04:22+09:00"])


class RecentOut(BaseModel):
    items: list[RecentItem] = Field(default_factory=list)
