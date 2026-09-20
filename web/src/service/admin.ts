import { requestModule } from "@/api/requestModule";

// 정지된 계정은 이후 요청이 403 이 되지만, 이미 발급된 액세스 토큰은 만료까지 유효하다
const changeUserStatus = (user_id: string, status: UserStatus) => {
    return requestModule.patch<ResponseProcess>(`/api/v1/admin/users/${user_id}`, { status });
};

const getApiCallMetrics = (params?: RequestApiCallsParams) => {
    return requestModule.get<ResponseApiCalls>('/api/v1/admin/metrics/api-calls', params);
};

const getLlmMetrics = () => {
    return requestModule.get<ResponseLlmMetrics>('/api/v1/admin/metrics/llm');
};

const getChatMetrics = () => {
    return requestModule.get<ResponseChatMetrics>('/api/v1/admin/metrics/chat');
};

const getMappingMetrics = () => {
    return requestModule.get<ResponseMappingMetrics>('/api/v1/admin/metrics/mapping');
};

const getVectorMetrics = () => {
    return requestModule.get<ResponseVectorMetrics>('/api/v1/admin/metrics/vectors');
};

// 관광지 1건당 상세 조회 1회 + 임베딩 1회를 소모한다
const buildAreaVectors = (signgu_cd: string, params?: RequestBuildVectorsParams) => {
    return requestModule.post<ResponseBuildVectors>(`/api/v1/admin/build-vectors/${signgu_cd}`, undefined, { params });
};

const loadAreaCodes = () => {
    return requestModule.post<ResponseLoadAreaCodes>('/api/v1/admin/load-area-codes');
};

export {
    changeUserStatus,
    getApiCallMetrics,
    getLlmMetrics,
    getChatMetrics,
    getMappingMetrics,
    getVectorMetrics,
    buildAreaVectors,
    loadAreaCodes
};
