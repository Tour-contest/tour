import { requestModule } from "@/api/requestModule";

const getRecentlySawTourists = () => {
    return requestModule.get<ResponseRecentlySawTourists>('/api/v1/me/recent-attractions');
};

const deleteRecentlySawTourists = () => {
    return requestModule.delete<ResponseProcess>('/api/v1/me/recent-attractions');
};

const getSearchTourist = (params: RequestSearchTouristParams) => {
    return requestModule.get<ResponseSearchTourist>('/api/v1/attractions/search', params);
};

// 호출 시 서버가 최근 본 관광지에 자동 기록한다
const getTouristDetail = (content_id: string) => {
    return requestModule.get<ResponseTouristDetail>(`/api/v1/attractions/${content_id}`);
};

const getSearchSimilarTourist = (content_id: string, limit?: number) => {
    return requestModule.get<ResponseSearchSimilarTourist>(`/api/v1/attractions/${content_id}/similar`, { limit })
};

const getAreaNameConversionAreaCode = (q: string) => {
    return requestModule.get<ResponseAreaNameConversionAreaCode>('/api/v1/areas/resolve', { q });
};

const getTouristCongestion = (content_id: string, params?: RequestTouristCongestion) => {
    return requestModule.get<ResponseTouristCongestion>(`/api/v1/attractions/${content_id}/crowd`, params);
};

const getSearchInterest = (content_id: string, weeks: number) => {
    return requestModule.get<ResponseSearchInterest>(`/api/v1/attractions/${content_id}/interest`, { weeks })
};

// 상세 응답의 pet 은 대화 경로에서만 채워지므로 화면은 이 API 를 따로 부른다
const getPetAttraction = (content_id: string) => {
    return requestModule.get<ResponsePetAttraction>(`/api/v1/attractions/${content_id}/pet`);
};

// 대표 이미지 1장은 검색/상세 응답의 image 로 오고, 갤러리(원본·썸네일·저작권)는 이 API 로 받는다
const getTouristImages = (content_id: string) => {
    return requestModule.get<ResponseTouristImages>(`/api/v1/attractions/${content_id}/images`);
};

const getAlternativesTourist = (content_id: string, params?: RequestAlternativesTourist) => {
    return requestModule.get<ResponseAlternativesTourist>(`/api/v1/attractions/${content_id}/alternatives`, params);
};

export {
    getRecentlySawTourists,
    deleteRecentlySawTourists,
    getSearchTourist,
    getTouristDetail,
    getSearchSimilarTourist,
    getAreaNameConversionAreaCode,
    getTouristCongestion,
    getSearchInterest,
    getPetAttraction,
    getTouristImages,
    getAlternativesTourist
};
