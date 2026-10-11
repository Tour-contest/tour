import { requestModule } from "@/api/requestModule";

const getAreas = () => {
    return requestModule.get<ResponseAreaList>('/api/v1/areas');
};

const getAreaOverview = (signgu_cd: string, params?: RequestAreaCrowdParams) => {
    return requestModule.get<ResponseAreaOverview>(`/api/v1/areas/${signgu_cd}/overview`, params);
};

// overview 와 응답 형태가 같다. 집계 없이 집중률 원자료만 필요할 때 사용한다
const getAreaCrowding = (signgu_cd: string, params?: RequestAreaCrowdParams) => {
    return requestModule.get<ResponseAreaOverview>(`/api/v1/areas/${signgu_cd}/crowding`, params);
};

const getAreaVisitors = (signgu_cd: string, params?: RequestAreaVisitorsParams) => {
    return requestModule.get<ResponseAreaVisitors>(`/api/v1/areas/${signgu_cd}/visitors`, params);
};

export {
    getAreas,
    getAreaOverview,
    getAreaCrowding,
    getAreaVisitors
};
