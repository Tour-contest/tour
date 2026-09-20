import type { AxiosInstance, InternalAxiosRequestConfig } from "axios";
import { isTokenExpired, requestRefresh, applyRefreshedToken, clearSession } from "./tokenManager";
import { useAuthenticateStore } from "@/store/authenticate";

const attachRefreshToken = (instance: AxiosInstance) => {
    if (!instance) return;

    instance.interceptors.request.use(async (config: InternalAxiosRequestConfig) => {
        const accessToken = useAuthenticateStore.getState().accessToken;
        const isRefreshCall = config.url?.includes("/auth/refresh");

        // refresh 의 인증 수단은 refresh_token 뿐이라 만료된 Bearer 를 실으면 서버가 거부할 수 있다
        if (!accessToken || isRefreshCall) return config;

        // 선제 검사: 만료 전이면 그대로 발송 (401 왕복 제거)
        if (!isTokenExpired(accessToken)) {
            config.headers.Authorization = `Bearer ${accessToken}`;
            return config;
        }

        try {
            const res = await requestRefresh();

            if (res.success) {
                applyRefreshedToken(res.data);
                config.headers.Authorization = `Bearer ${res.data.access_token}`;
                return config;
            }
        } catch (e) {
            console.error(e);
        }

        clearSession();
        return Promise.reject(new Error("세션이 만료되었습니다."));
    });
};
export default attachRefreshToken;
