import { requestModule } from "@/api/requestModule";

const getUser = (params?: GetUserParams) => {
    return requestModule.get<ResponseUserList>("/api/v1/admin/users", params)
};

const getMyInfo = () => {
    return requestModule.get<ResponseMyInfo>("/api/v1/me")
};

export { 
    getUser, 
    getMyInfo,
};