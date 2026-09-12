import { requestModule } from "@/api/requestModule";

const adminAuthenticate = (loginId: string, password: string) => {
    return requestModule.post('/api/v1/auth/login', { login_id: loginId, password })
};

export { adminAuthenticate };