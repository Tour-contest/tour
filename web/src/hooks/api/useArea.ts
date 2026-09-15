import {
    getAreas,
    getAreaOverview,
    getAreaCrowding,
    getAreaVisitors
} from "@/service/area";

const useArea = () => {
    const fetchAreas = async () => {
        try {
            const res = await getAreas();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchAreaOverview = async (signguCd: string, params?: RequestAreaCrowdParams) => {
        try {
            const res = await getAreaOverview(signguCd, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchAreaCrowding = async (signguCd: string, params?: RequestAreaCrowdParams) => {
        try {
            const res = await getAreaCrowding(signguCd, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchAreaVisitors = async (signguCd: string, params?: RequestAreaVisitorsParams) => {
        try {
            const res = await getAreaVisitors(signguCd, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    return {
        fetchAreas,
        fetchAreaOverview,
        fetchAreaCrowding,
        fetchAreaVisitors
    };
};
export default useArea;
