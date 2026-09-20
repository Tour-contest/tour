import { requestModule } from "@/api/requestModule";

// 아래 3개는 인증이 필요 없는 엔드포인트다
const getHealth = () => {
    return requestModule.get<ResponseHealth>('/api/v1/healthz');
};

const getReady = () => {
    return requestModule.get<ResponseReady>('/api/v1/readyz');
};

const getAttribution = () => {
    return requestModule.get<ResponseAttribution>('/api/v1/meta/attribution');
};

export {
    getHealth,
    getReady,
    getAttribution
};
