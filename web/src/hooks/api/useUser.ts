import { getUser, getMyInfo } from "@/service/user";

const useUser = () => {
    const fetchUsers = async (params?: GetUserParams) => {
        try {
            const res = await getUser(params);
            console.log({ res });
            return res;
        } catch (e) {
            console.error(e);
            return null;
        }
    };

    const fetchMyInfo = async () => {
        try {
            const res = await getMyInfo();
            console.log({ res });
        } catch (e) {
            console.error(e);
        }
    };

    return { 
        fetchUsers, 
        fetchMyInfo 
    };
};
export default useUser;
