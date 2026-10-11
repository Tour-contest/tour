declare global {
    // 서버 생존 확인 — 프로세스만 확인하며 DB·상류 상태는 보지 않는다
    type HealthData = {
        ok: boolean;
    };

    type ResponseHealth = ResponseSuccessData<HealthData>;

    // 기능 활성 확인 — 첫 화면의 기능 활성 판단에 사용한다 (인증 불필요)
    type ReadyData = {
        ok: boolean;
        areas_loaded: number;      // 0 이면 지역 조회가 동작하지 않는다
        llm_enabled: boolean;      // false 면 대화가 규칙 기반으로 동작 (응답 형태는 동일)
        llm_model: string | null;
        embedding_ready: boolean;  // false 면 유사 관광지가 빈 상태로 응답
        service_key_set: boolean;  // false 면 관광 데이터 조회가 전부 실패
    };

    type ResponseReady = ResponseSuccessData<ReadyData>;

    // 출처 표기 문구 (인증 불필요)
    type AttributionData = {
        text: string;
        note: string;
    };

    type ResponseAttribution = ResponseSuccessData<AttributionData>;
};
