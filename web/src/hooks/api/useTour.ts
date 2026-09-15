import { 
    getRecentlySawTourists,
    deleteRecentlySawTourists,
    getSearchTourist,
    getSearchSimilarTourist,
    getAreaNameConversionAreaCode,
    getTouristCongestion 
} from "@/service/tour";

const useTour = () => {
    const fetchRecentlySawTourists = async () => {
        try {
            const res = await getRecentlySawTourists();
            console.log({ res });
        } catch (e) {
            console.error(e);
        };
    };

    const handleDeleteRecentlySawTourist = async () => {
        try {
            await deleteRecentlySawTourists();
        } catch (e) {
            console.error(e);
        };
    };

    const handleSearchTourist = async (params: RequestSearchTouristParams) => {
        try {
            const res = await getSearchTourist(params) as ResponseSearchTourist;
            console.log({ res });
        } catch (e) {
            console.error(e);
        };
    };

    const handleSearchSimilarTourists = async (contentId: string, limit?: number) => {
        try {
            const res = await getSearchSimilarTourist(contentId, limit) as ResponseSearchSimilarTourist;
            console.log({ res });
        } catch (e) {
            console.error(e);
        };
    };

    const handleSearchConversedAreaCode = async (q: string) => {
        try {
            const res = await getAreaNameConversionAreaCode(q) as ResponseAreaNameConversionAreaCode;
            console.log({ res });
        } catch (e) {
            console.error(e);
        };
    };

    const handleSearchTouristCongesion = async (content_id: string, params?: RequestTouristCongestion) => {
        try {
            const res = await getTouristCongestion(content_id, params) as ResponseTouristCongestion;
            console.log({ res });
        } catch (e) {
            console.error(e);
        }; 
    };

    return {
        fetchRecentlySawTourists,
        handleDeleteRecentlySawTourist,
        handleSearchTourist,
        handleSearchSimilarTourists,
        handleSearchConversedAreaCode,
        handleSearchTouristCongesion
    };
};
export default useTour;