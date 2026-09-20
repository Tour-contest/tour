import { getHealth, getReady, getAttribution } from "@/service/system";

const useSystem = () => {
    const fetchHealth = async () => {
        try {
            const res = await getHealth();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    // 첫 화면의 기능 활성 판단용 (지역코드 적재 / LLM / 임베딩 / 서비스키)
    const fetchReady = async () => {
        try {
            const res = await getReady();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchAttribution = async () => {
        try {
            const res = await getAttribution();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    return {
        fetchHealth,
        fetchReady,
        fetchAttribution
    };
};
export default useSystem;
