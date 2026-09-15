import { requestModule } from "@/api/requestModule";

const getUser = (params?: GetUserParams) => {
    return requestModule.get("/api/v1/admin/users", params)
};

const getMyInfo = () => {
    return requestModule.get("/api/v1/me")
};

export { 
    getUser, 
    getMyInfo,
};