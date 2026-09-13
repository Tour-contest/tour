from __future__ import annotations

from pydantic import BaseModel, Field

from app.schemas.common import Loose


class AreaItem(BaseModel):
    signgu_cd: str = Field(description="시군구 코드", examples=["44825"])
    signgu_nm: str = Field(examples=["태안군"])


class SidoGroup(BaseModel):
    sido_nm: str = Field(description="시도명", examples=["충청남도"])
    items: list[AreaItem] = Field(description="해당 시도의 시군구 목록")


class AreaListOut(BaseModel):
    count: int = Field(description="전체 시군구 수", examples=[268])
    sido: list[SidoGroup] = Field(description="시도별로 묶은 시군구 목록")


class AreaCandidate(BaseModel):
    signgu_cd: str = Field(examples=["51820"])
    label: str = Field(description="시도까지 붙인 이름", examples=["강원특별자치도 고성군"])


class ResolveOut(BaseModel):
    status: str = Field(description="ok · ambiguous · not_found", examples=["ok"])
    signgu_cd: str | None = Field(None, examples=["44825"])
    signgu_nm: str | None = Field(None, examples=["태안군"])
    sido_nm: str | None = Field(None, examples=["충청남도"])
    label: str | None = Field(None, examples=["충청남도 태안군"])
    tour_cd: str | None = Field(None, description="관광정보 쪽 지역 코드", examples=["34_14"])
    crowd_cd: str | None = Field(None, description="혼잡도 쪽 지역 코드", examples=["44825"])
    candidates: list[AreaCandidate] | None = Field(
        None, description="ambiguous 일 때만. 임의로 첫 번째를 고르지 말고 선택 UI 를 띄운다"
    )
    hint: str | None = Field(None, description="not_found 일 때 다시 물어볼 문구")
    note: str | None = Field(
        None, description="읍면동을 시군구로 추정했을 때의 안내",
        examples=["'애월' 일대는 제주특별자치도 제주시 기준으로 안내합니다"],
    )


class CrowdSample(BaseModel):
    name: str = Field(description="혼잡도 쪽 관광지 이름", examples=["운여해변"])
    rate: float = Field(description="집중률. % 를 붙이지 않는다", examples=[28.4])
    content_id: str | None = Field(None, description="상세로 넘어갈 수 있으면 채워진다",
                                   examples=["126266"])
    image: str | None = Field(None, description="대표 이미지. 없으면 빈 문자열")


class Coverage(BaseModel):
    tourapi_total: int | None = Field(None, description="관광정보에 등록된 곳 수", examples=[214])
    with_crowd_data: int = Field(description="그중 혼잡도 자료가 있는 곳 수", examples=[36])


class OverviewOut(BaseModel):
    status: str = Field(description="ok · no_data", examples=["ok"])
    signgu_cd: str | None = Field(None, examples=["44825"])
    signgu_nm: str = Field(examples=["태안군"])
    date: str | None = Field(None, description="기준 날짜", examples=["2026-09-06"])
    summary: dict[str, int] | None = Field(
        None, description="등급별 곳 수", examples=[{"crowded": 3, "normal": 11, "quiet": 22}]
    )
    samples: dict[str, list[CrowdSample]] | None = Field(
        None, description="등급별 샘플. 한적부터 보여주면 된다"
    )
    coverage: Coverage | None = None
    merged_from: list[str] | None = Field(
        None, description="구가 있는 시라서 하위 구를 모아 계산했을 때 그 구 목록"
    )
    message: str | None = Field(None, description="no_data 일 때 보여줄 문구")
    source: str | None = Field(None, examples=["출처: ⓒ한국관광공사"])


class VisitorPoint(Loose):
    date: str = Field(examples=["2026-06-15"])
    total: float = Field(description="그 주 방문자 수 합", examples=[41233])


class VisitorsOut(BaseModel):
    status: str = Field(description="ok · no_data", examples=["ok"])
    signgu_nm: str | None = Field(None, examples=["태안군"])
    items: list[VisitorPoint] = Field(description="주 단위. 구분(local·outsider·foreigner)은 키로 더 붙는다")
    data_through: str = Field(
        description="이 날짜까지의 자료다. 화면에 반드시 같이 표시할 것", examples=["2026-06-23"]
    )
    note: str | None = Field(None, examples=["통신 데이터 기반이며 두 달쯤 지연된 값입니다"])
