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

const getSearchSimilarTourist = (content_id: string, limit?: number) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/similar`, { limit })
};

const getAreaNameConversionAreaCode = (q: string) => {
    return requestModule.get('/api/v1/areas/resolve', { q });
};

const getTouristCongestion = (content_id: string, params?: RequestTouristCongestion) => {
    return requestModule.get(`/api/v1/attractions/${content_id}/crowd`, params);
};

export { 
    getRecentlySawTourists,
    deleteRecentlySawTourists,
    getSearchTourist,
    getSearchSimilarTourist,
    getAreaNameConversionAreaCode,
    getTouristCongestion
};