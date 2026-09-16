import { getUser, getMyInfo } from "@/service/user";
import { useState } from "react";

const useUser = () => {
    const [myInfo, setMyInfo] = useState<MyInfo>();
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
            const res = await getMyInfo() as ResponseMyInfo;
            if (!res.success) return;
            const myInformation = res.data as MyInfo;
            setMyInfo(myInformation);
        } catch (e) {
            console.error(e);
        }
    };

    return { 
        fetchUsers, 
        fetchMyInfo,
        myInfo 
    };
};
export default useUser;
