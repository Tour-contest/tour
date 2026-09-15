declare global {
    // 최근 본 관광지 조회
    type RecentlySawTourists = {
        content_id: string;
        title: string;
        signgu_cd: string;
        signgu_nm: string;
        last_level: "혼잡" | "보통" | "한적";
        viewed_at: string;
    };

    type ResponseRecentlySawTourists = ResponseSuccessData<{ items: RecentlySawTourists[] }>

    // 관광지 이름 검색
    type RequestSearchTouristParams = {
        keyword: string;
        signgu_cd?: string;
    };

    type SearchTouristContext = {
        content_id: string;
        title: string;
        addr1: string;
        content_type_id: string;
        image: string;
        mapx: number;
        mapy: number;
        signgu_cd: string;
        signgu_nm: string;
    };

    type SearchTouristData = {
        status: "ok";
        confident: boolean;
        items: SearchTouristContext[];
        source: string;
    };

    type ResponseSearchTourist = ResponseSuccessData<SearchTouristData>;

    // 유사 관광지
    type SearchSimilarTouristContext = {
        content_id: string;
        title: string;
        lcls1: "NA" | "HS" | "VE" | "EX" | "LS" | "EV" | "SH" | "FD" | "AC";
        lcls2: string;
        similarity: number;
    };

    type SearchSimilarTouristData = {
        status: "ok";
        items: SearchSimilarTouristContext[];
        source: string;
    };

    type ResponseSearchSimilarTourist = ResponseSuccessData<SearchSimilarTouristData>;

    // 지역명 -> 코드 변환
    type ResultCandidates = {
        signgu_cd: string;
        label: string;
    };

    type AreaNameConversionAreaCodeData = {
        status: "ok" | "ambiguous" | "not_found";
        signgu_cd?: string;
        signgu_nm?: string;
        sido_nm?: string;
        label?: string;
        tour_cd?: string;
        crowd_cd?: string;
        candidates?: ResultCandidates[];
        hint?: string;
    };

    type ResponseAreaNameConversionAreaCode = ResponseSuccessData<AreaNameConversionAreaCodeData>;

    // 관광지 혼잡도
    type RequestTouristCongestion = {
        days: number;
        date_from: string;
    };

    type TouristCongestionSeries = {
        date: string;
        weekday: "월" | "화" | "수" | "목" | "금" | "토" | "일";
        rate: number;
        level: "혼잡" | "보통" | "한적";
    };

    type TouristCongestionSummary = {
        peak_date: string;
        peak_rate: number;
        min_date: string;
        min_rate: number;
        avg: number;
    };

    type TouristCongestionData = {
        status: "ok" | "no_data";
        content_id: string;
        has_data: boolean;
        matched_name?: string;
        match_method?: "exact" | "keyword" | "reverse";
        match_confidence?: number;
        series: TouristCongestionSeries[];
        summary: TouristCongestionSummary;
        available_days?: number;
        message?: string;
        signgu_cd: string;
        signgu_nm: string;
        source?: string;
    };

    type ResponseTouristCongestion = ResponseSuccessData<TouristCongestionData>;
};