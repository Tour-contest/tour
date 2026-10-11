// 상세 화면의 표시 규칙과 응답 변환 (순수 함수 · 상수)

export const CONTENT_TYPE_LABEL: Record<string, string> = {
    "12": "관광지",
    "14": "문화시설",
    "15": "행사",
    "25": "여행코스",
    "28": "레포츠",
    "32": "숙박",
    "38": "쇼핑",
    "39": "음식점",
};

export const LCLS1_LABEL: Record<SearchSimilarTouristContext["lcls1"], string> = {
    NA: "자연",
    HS: "역사",
    VE: "휴양",
    EX: "체험",
    LS: "레포츠",
    EV: "행사",
    SH: "쇼핑",
    FD: "음식",
    AC: "숙박",
};

// 관광지 지정 혼잡도 REST 응답을 대화 카드 payload 형태로 바꿔 같은 카드로 그린다
export const toCrowdPayload = (title: string, congestion: TouristCongestionData): ChatCrowdAttractionPayload => ({
    status: congestion.status,
    signgu_cd: congestion.signgu_cd,
    signgu_nm: congestion.signgu_nm,
    source: congestion.source,
    items: [{
        content_id: congestion.content_id,
        name: title,
        matched_title: congestion.matched_name,
        match_method: congestion.match_method,
        series: congestion.series ?? [],
        summary: congestion.summary,
        available_days: congestion.available_days,
    }],
});
