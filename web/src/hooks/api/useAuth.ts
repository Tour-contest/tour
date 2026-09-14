import { isAxiosError } from "axios";
import { adminAuthenticate, devAuthenticate, authenticateProviders, socialAuthenticate } from "@/service/auth";
import { useAuthenticateStore } from "@/store/authenticate";
import { useAuthorityStore } from "@/store/authority";
import type { ErrorResponse } from "@/types/error";

export type SocialLoginPayload = {
    provider: string;
    code: string;
    redirectUri: string;
};

export type AdminLoginState = {
    isSuccess: boolean;
    errorMessage: string | null;
};

export const INITIAL_ADMIN_LOGIN_STATE: AdminLoginState = {
    isSuccess: false,
    errorMessage: null,
};

const resolveAuthErrorMessage = (e: unknown, fallback: string): string => {
    if (isAxiosError<ErrorResponse>(e) && e.response?.data.message) {
        return e.response.data.message;
    }
    return fallback;
};

const useAuth = () => {
    const setAuthenticate = useAuthenticateStore((state) => state.setAuthenticate);
    const setAuthority = useAuthorityStore((state) => state.setAuthority);

    // 로그인 수단(관리자/개발자/소셜)이 달라도 성공 응답 형태는 같으므로 반영 경로는 하나로 둔다
    const applyAuthenticated = ({ data }: ResponseAutenticate) => {
        setAuthenticate(data);
        setAuthority(data.access_token);
    };

    const fetchAuthenticateProvider = async (): Promise<ResponseProviderData | null> => {
        try {
            const res = await authenticateProviders();
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        }
    };

    const handleAdminLogin = async (
        _previousState: AdminLoginState,
        formData: FormData,
    ): Promise<AdminLoginState> => {
        const loginId = formData.get("loginId")?.toString() ?? "";
        const password = formData.get("password")?.toString() ?? "";

        try {
            const res = await adminAuthenticate(loginId, password);
            applyAuthenticated(res);
            return { isSuccess: true, errorMessage: null };
        } catch (e) {
            console.error(e);
            return { isSuccess: false, errorMessage: resolveAuthErrorMessage(e, "로그인에 실패했습니다. 잠시 후 다시 시도해주세요.") };
        };
    };

    // 테스트용 개발자 로그인 (API 명세 기준 nickname 하나만 받음)
    const handleDevLogin = async (
        _previousState: AdminLoginState,
        nickname: string,
    ): Promise<AdminLoginState> => {
        try {
            const res = await devAuthenticate(nickname);
            applyAuthenticated(res);
            return { isSuccess: true, errorMessage: null };
        } catch (e) {
            console.error(e);
            return { isSuccess: false, errorMessage: resolveAuthErrorMessage(e, "개발자 로그인에 실패했습니다.") };
        };
    };

    const handleSocialLogin = async (
        _previousState: AdminLoginState,
        { provider, code, redirectUri }: SocialLoginPayload,
    ): Promise<AdminLoginState> => {
        try {
            const res = await socialAuthenticate(provider, code, redirectUri);
            applyAuthenticated(res);
            return { isSuccess: true, errorMessage: null };
        } catch (e) {
            console.error(e);
            return { isSuccess: false, errorMessage: resolveAuthErrorMessage(e, "소셜 로그인에 실패했습니다.") };
        };
    };

    return { fetchAuthenticateProvider, handleAdminLogin, handleDevLogin, handleSocialLogin }
}
export default useAuth;
