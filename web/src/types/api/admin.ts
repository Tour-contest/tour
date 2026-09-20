declare global {
    // 사용자 상태 변경
    type UserStatus = "active" | "suspended";

    type RequestChangeUserStatus = {
        status: UserStatus;
    };

    // 공공데이터 호출 이력 — 심사용 API 활용 내역 화면을 겸한다
    // 서버 문서(OpenAPI) 기준: limit 1~500 (기본 100) · day YYYY-MM-DD (기본 오늘 KST). offset 은 없다.
    // provider 는 문서에 "tourapi, naver" 라 적혀 있지만 실제 비교는 로그에 저장된 값(data.go.kr · naver)으로 한다 — tourapi 를 보내면 0건
    type ApiCallProvider = "data.go.kr" | "naver";

    type RequestApiCallsParams = {
        limit?: number;
        provider?: ApiCallProvider;
        day?: string;
    };

    type ApiCallQuota = {
        limit: number;
        used_today: number;
        remaining: number;   // 0 이면 조회 기능이 중단된 상태임을 크게 표시한다
    };

    type ApiCallDaily = {
        date: string;
        real: number;     // 상류에 실제로 나간 호출 수
        cached: number;   // 중복 제거로 절약한 호출 수
    };

    type ApiCallLlmUsage = {
        calls: number;
        prompt: number;
        completion: number;
        since: string;   // 메모리 카운터라 재기동 시 0부터 재집계
    };

    type ApiCallLog = {
        id: number;
        session_id: string | null;
        provider: "data.go.kr" | "naver";
        operation: string;
        params: string | null;   // serviceKey 는 마스킹된다
        status_code: number | null;
        result_code: string | null;
        latency_ms: number | null;
        cache_hit: 0 | 1;
        called_at: string;
    };

    type ApiCallsData = {
        date: string;
        quota: ApiCallQuota;
        by_operation: Record<string, number>;
        error_rate: number;      // 0~1, 화면에서는 ×100
        avg_latency_ms: number;
        cache_hits: number;
        cache_rate: number;      // 0~1
        cache_enabled: boolean;  // 1회 요청 내 중복 제거 여부. 원천 저장 캐시가 아니다
        daily: ApiCallDaily[];
        llm: ApiCallLlmUsage;
        recent: ApiCallLog[];
    };

    type ResponseApiCalls = ResponseSuccessData<ApiCallsData>;

    // 모델 사용량·비용
    type LlmPricePer1m = {
        in: number;
        out: number;
    };

    type LlmByPurpose = {
        purpose: "tool" | "optimize" | "compose" | "summary";
        calls: number;
        tokens: number;
    };

    type LlmDaily = {
        date: string;
        prompt: number;
        completion: number;
        calls: number;
        cost_usd: number;
    };

    type LlmMetricsData = {
        date: string;
        model: string;
        price_per_1m: LlmPricePer1m;
        calls: number;
        prompt_tokens: number;
        completion_tokens: number;
        avg_latency_ms: number;
        rate_limited: number;
        errors: number;
        by_purpose: LlmByPurpose[];
        cost_today_usd: number;   // 토큰은 실측, 비용은 단가 환산값
        daily: LlmDaily[];
    };

    type ResponseLlmMetrics = ResponseSuccessData<LlmMetricsData>;

    // 대화 통계
    type ChatMetricsDaily = {
        date: string;
        count: number;
    };

    type ChatTopAttraction = {
        title: string;
        count: number;
    };

    type ChatMetricsData = {
        daily: ChatMetricsDaily[];
        sessions: number;
        users: number;
        top_attractions: ChatTopAttraction[];
    };

    type ResponseChatMetrics = ResponseSuccessData<ChatMetricsData>;

    // 이름 매핑 현황 — 화면에는 matched / total 을 ×100 한 매칭률로 표시한다
    type MappingMetricsData = {
        total: number;
        matched: number;
        areas: number;
    };

    type ResponseMappingMetrics = ResponseSuccessData<MappingMetricsData>;

    // 벡터 현황
    type VectorMetricsData = {
        vectors: number;
        areas: number;
        available: boolean;   // false 이면 유사 관광지가 no_data 로 응답한다
    };

    type ResponseVectorMetrics = ResponseSuccessData<VectorMetricsData>;

    // 지역 벡터 생성
    type RequestBuildVectorsParams = {
        limit?: number;
    };

    type BuildVectorsData = {
        status: "ok" | "unavailable";
        built: number;
        total: number | null;
        signgu_nm: string | null;
    };

    type ResponseBuildVectors = ResponseSuccessData<BuildVectorsData>;

    // 지역 코드표 재적재 — 상류 할당량을 소모하므로 초기 1회로 충분하다
    type LoadAreaCodesData = {
        categories: number;
        tour: number;
        crowd: number;
        saved: number;
        code_differs: number;
        tour_unmatched: string[];
    };

    type ResponseLoadAreaCodes = ResponseSuccessData<LoadAreaCodesData>;
};
