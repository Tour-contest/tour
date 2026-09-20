import {
    changeUserStatus,
    getApiCallMetrics,
    getLlmMetrics,
    getChatMetrics,
    getMappingMetrics,
    getVectorMetrics,
    buildAreaVectors,
    loadAreaCodes
} from "@/service/admin";

const useAdmin = () => {
    const handleChangeUserStatus = async (userId: string, status: UserStatus) => {
        try {
            const res = await changeUserStatus(userId, status);
            return res.data.ok;
        } catch (e) {
            console.error(e);
            return false;
        };
    };

    const fetchApiCallMetrics = async (params?: RequestApiCallsParams) => {
        try {
            const res = await getApiCallMetrics(params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchLlmMetrics = async () => {
        try {
            const res = await getLlmMetrics();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchChatMetrics = async () => {
        try {
            const res = await getChatMetrics();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchMappingMetrics = async () => {
        try {
            const res = await getMappingMetrics();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchVectorMetrics = async () => {
        try {
            const res = await getVectorMetrics();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const handleBuildAreaVectors = async (signguCd: string, params?: RequestBuildVectorsParams) => {
        try {
            const res = await buildAreaVectors(signguCd, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const handleLoadAreaCodes = async () => {
        try {
            const res = await loadAreaCodes();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    return {
        handleChangeUserStatus,
        fetchApiCallMetrics,
        fetchLlmMetrics,
        fetchChatMetrics,
        fetchMappingMetrics,
        fetchVectorMetrics,
        handleBuildAreaVectors,
        handleLoadAreaCodes
    };
};
export default useAdmin;
