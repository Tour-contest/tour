import { getUser, getMyInfo } from "@/service/user";
import { useState } from "react";

const useUser = () => {
    const [myInfo, setMyInfo] = useState<MyInfo>();
    // 관리자 회원 목록. 다른 fetch* 와 같이 응답 본문(data)만 돌려준다
    const fetchUsers = async (params?: GetUserParams): Promise<AdminUserListData | null> => {
        try {
            const res = await getUser(params);
            return res.data;
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
