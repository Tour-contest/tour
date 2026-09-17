import {
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
} from "@/service/tour";

const useTour = () => {
    const fetchRecentlySawTourists = async () => {
        try {
            const res = await getRecentlySawTourists();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const handleDeleteRecentlySawTourist = async () => {
        try {
            const res = await deleteRecentlySawTourists();
            return res.data.ok;
        } catch (e) {
            console.error(e);
            return false;
        };
    };

    const fetchSearchTourist = async (params: RequestSearchTouristParams) => {
        try {
            const res = await getSearchTourist(params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    // 호출만으로 최근 본 관광지에 기록되므로 상세 화면 진입 시 한 번만 부른다
    const fetchTouristDetail = async (contentId: string) => {
        try {
            const res = await getTouristDetail(contentId);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchSimilarTourists = async (contentId: string, limit?: number) => {
        try {
            const res = await getSearchSimilarTourist(contentId, limit);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchConversedAreaCode = async (q: string) => {
        try {
            const res = await getAreaNameConversionAreaCode(q);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchTouristCongestion = async (contentId: string, params?: RequestTouristCongestion) => {
        try {
            const res = await getTouristCongestion(contentId, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchSearchInterest = async (contentId: string, weeks: number) => {
        try {
            const res = await getSearchInterest(contentId, weeks);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchPetAttraction = async (contentId: string) => {
        try {
            const res = await getPetAttraction(contentId);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchTouristImages = async (contentId: string) => {
        try {
            const res = await getTouristImages(contentId);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchAlternativesTourist = async (contentId: string, params?: RequestAlternativesTourist) => {
        try {
            const res = await getAlternativesTourist(contentId, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    return {
        fetchRecentlySawTourists,
        handleDeleteRecentlySawTourist,
        fetchSearchTourist,
        fetchTouristDetail,
        fetchSimilarTourists,
        fetchConversedAreaCode,
        fetchTouristCongestion,
        fetchSearchInterest,
        fetchPetAttraction,
        fetchTouristImages,
        fetchAlternativesTourist
    };
};
export default useTour;
