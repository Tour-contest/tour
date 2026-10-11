declare global {
    // 시군구 전체 목록 — 값이 거의 변동하지 않으므로 클라이언트 캐싱을 권장한다
    type AreaItem = {
        signgu_cd: string;
        signgu_nm: string;
    };

    type SidoGroup = {
        sido_nm: string;
        items: AreaItem[];
    };

    type AreaListData = {
        count: number;
        sido: SidoGroup[];
    };

    type ResponseAreaList = ResponseSuccessData<AreaListData>;

    // 지역 혼잡 현황(overview) / 지역 혼잡도 1일치(crowding) — 응답 형태가 동일하다
    type RequestAreaCrowdParams = {
        date?: string;
    };

    // 값은 곳 수이며 퍼센트가 아니다
    type AreaCrowdSummary = {
        crowded: number;
        normal: number;
        quiet: number;
    };

    type AreaCrowdSample = {
        name: string;
        rate: number;
        content_id?: string | null;
        image?: string | null;
    };

    // 각 등급 최대 15곳, 집중률 오름차순
    type AreaCrowdSamples = {
        quiet: AreaCrowdSample[];
        normal: AreaCrowdSample[];
        crowded: AreaCrowdSample[];
    };

    // "관광정보 N곳 중 집중률 보유 M곳" 문구로 표기한다
    type AreaCrowdCoverage = {
        tourapi_total: number;
        with_crowd_data: number;
    };

    type AreaOverviewData = {
        status: "ok" | "no_data" | "not_found";
        signgu_cd: string;
        signgu_nm: string;
        date: string;
        summary?: AreaCrowdSummary;
        samples?: AreaCrowdSamples;
        coverage?: AreaCrowdCoverage;
        merged_from?: string[];
        message?: string;
        source?: string;
    };

    type ResponseAreaOverview = ResponseSuccessData<AreaOverviewData>;

    // 지역 방문자 추세 — 약 75일 지연된 값이라 data_through 를 반드시 함께 표기한다
    type RequestAreaVisitorsParams = {
        weeks?: number;
    };

    type AreaVisitorItem = {
        date: string;
        total: number;
        local?: number;
        outsider?: number;
        foreigner?: number;
    };

    type AreaVisitorsData = {
        status: "ok" | "no_data";
        signgu_nm?: string;
        items: AreaVisitorItem[];
        data_through: string;
        note?: string;
        partial: boolean;
    };

    type ResponseAreaVisitors = ResponseSuccessData<AreaVisitorsData>;
};
