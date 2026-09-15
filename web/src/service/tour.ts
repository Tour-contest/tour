import { requestModule } from "@/api/requestModule";

const getRecentlySawTourists = () => {
    return requestModule.get('/api/v1/me/recent-attractions');
};

const deleteRecentlySawTourists = () => {
    return requestModule.delete('/api/v1/me/recent-attractions');
};

const getSearchTourist = (params: RequestSearchTouristParams) => {
    return requestModule.get('/api/v1/attractions/search', params);
};

// 호출 시 서버가 최근 본 관광지에 자동 기록한다
const getTouristDetail = (content_id: string) => {
    return requestModule.get<ResponseTouristDetail>(`/api/v1/attractions/${content_id}`);
};

const getSearchSimilarTourist = (content_id: string, limit?: number) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/similar`, { limit })
};

const getAreaNameConversionAreaCode = (q: string) => {
    return requestModule.get('/api/v1/areas/resolve', { q });
};

const getTouristCongestion = (content_id: string, params?: RequestTouristCongestion) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/crowd`, params);
};

const getSearchInterest = (content_id: string, weeks: number) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/interest`, { weeks })
};

const getPetAttraction = (content_id: string) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/pet`);
};

const getTouristImages = (content_id: string) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/images`);
};

const getAlternativesTourist = (content_id: string, params?: RequestAlternativesTourist) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/alternatives`, params);
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