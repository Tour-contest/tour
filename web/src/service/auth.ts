import { requestModule } from "@/api/requestModule";

const authenticateProviders = () => {
    return requestModule.get<ResponseAutenticateProvider>('/api/v1/auth/providers');
};

const adminAuthenticate = (loginId: string, password: string) => {
    return requestModule.post<ResponseAutenticate>('/api/v1/auth/login', { login_id: loginId, password })
};

const devAuthenticate = (nickname?: string) => {
    return requestModule.post<ResponseAutenticate>('/api/v1/auth/dev-login', { nickname })
};

// code+redirect_uri(웹 인가 코드 흐름) 조합만 사용 — 네이티브 SDK 의 access_token 단독 전송 경로는 미지원
const socialAuthenticate = (provider: string, code: string, redirectUri: string) => {
    return requestModule.post<ResponseAutenticate>(`/api/v1/auth/oauth/${provider}/callback`, {
        code,
        redirect_uri: redirectUri,
    })
};

// 이 서버는 refresh_token 을 쿠키가 아니라 요청 바디로 받는다 (미전송 시 422 INVALID_INPUT)
const requestRefresh = (refreshToken: string) => {
    return requestModule.post<ResponseAutenticate>('/api/v1/auth/refresh', { refresh_token: refreshToken })
;}

const logout = () => {
    return requestModule.post<ResponseLogout>('/api/v1/auth/logout')
};

const withdrawMembership = () => {
    return requestModule.delete("/api/v1/me");
};

export { 
    authenticateProviders, 
    adminAuthenticate, 
    devAuthenticate, 
    socialAuthenticate, 
    requestRefresh, 
    logout,
    withdrawMembership 
};