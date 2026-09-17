declare global {
    // 관광지 상세 — 호출 시 최근 본 관광지에 자동 기록된다
    // OpenAPI 문서는 name 이라고 적혀 있지만 실제 응답은 label 로 온다 (2026-09-17 확인). /pet 항목과 같은 형태
    type TouristDetailInfo = {
        label: string;
        value: string;
    };

    type TouristDetailData = {
        status: "ok";
        content_id: string;
        title?: string | null;
        addr1?: string | null;
        tel?: string | null;
        overview?: string | null;   // 화면은 400자까지 표시. HTML 엔티티가 섞여 올 수 있다
        image?: string | null;      // 없으면 빈 문자열
        mapx?: number | null;       // 지도 버튼 노출 조건
        mapy?: number | null;
        content_type_id?: string | null;   // 12 관광지 / 14 문화시설 / 15 행사 / 25 여행코스 / 28 레포츠 / 32 숙박 / 38 쇼핑 / 39 음식점
        signgu_cd?: string | null;
        signgu_nm?: string | null;
        sido_nm?: string | null;
        info: TouristDetailInfo[];         // 비어 있으면 카드를 표시하지 않는다
        pet: PetAttractionContext[];       // 대화 경로에서만 채워진다. 화면은 /pet 을 따로 호출
        source?: string | null;
    };

    type ResponseTouristDetail = ResponseSuccessData<TouristDetailData>;

    // 최근 본 관광지 조회
    type RecentlySawTourists = {
        content_id: string;
        title: string;
        signgu_cd: string;
        signgu_nm: string;
        last_level: CrowdLevel;
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
        level: CrowdLevel;
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

    // 검색 관심도 추세
    type SearchInterestContext = {
        name: string;
        display_name: string;
        trend: 'rising' | 'falling' | 'flat';
        change_pct: number;
        weeks: number;
    };

    type SearchInterestData = {
        status: "ok" | "no_data";
        items: SearchInterestContext[];
    };

    type ResponseSearchInterest = ResponseSuccessData<SearchInterestData>;

    // 반려동물 동반 정보
    type PetAttractionContext = {
        label: string;
        value: string;
    };

    type PetAttractionData = {
        status: "ok" | "no_data";
        items: PetAttractionContext[];
        source: string;
    };

    type ResponsePetAttraction = ResponseSuccessData<PetAttractionData>;

    // 관광지 이미지 목록
    type TouristImagesContext = {
        url: string;
        small: string;
        name: string;
        copyright: string;
    };

    type TouristImagesData = {
        status: "ok" | "no_data";
        items: TouristImagesContext[];
        source: string;
    };

    type ResponseTouristImages = ResponseSuccessData<TouristImagesData>

    // 덜 붐비는 대안 추천
    type RequestAlternativesTourist = {
        date: string;
        limit: number;
    };

    type AlternativesTouristBase = {
        name: string;
        rate: number;
        level: CrowdLevel;
    };

    type AlternativesTouristReason = {
        lower_by: number;
        distance_km: number;
        same_category: boolean;
        similarity: number;
    };

    type AlternativesTouristContext = {
        content_id: string;
        name: string;
        rate: number;
        level: CrowdLevel;
        date: string;
        addr1: string;
        image: string;
        reason: AlternativesTouristReason;
    };

    type AlternativesTouristData = {
        status: "ok" | "no_data";
        signgu_nm: string;
        base: AlternativesTouristBase;
        items: AlternativesTouristContext[];
        sort_basis: "crowding" | "none";
        relaxed: boolean;
        candidate_source: "related" | "area" | "related+area";
        source: string;
    };

    type ResponseAlternativesTourist = ResponseSuccessData<AlternativesTouristData>;
};