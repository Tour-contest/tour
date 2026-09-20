import { create } from "zustand";

const ACCESS_TOKEN_KEY = "accessToken";
const REFRESH_TOKEN_KEY = "refreshToken";
const USER_KEY = "user";

// authority store / tokenManager 가 새로고침 직후 토큰을 복원할 때도 같은 키를 쓰도록 여기서 노출한다
export const readStoredAccessToken = () => sessionStorage.getItem(ACCESS_TOKEN_KEY);

const readStoredUser = (): UserInfo | null => {
    const stored = sessionStorage.getItem(USER_KEY);
    if (!stored) return null;

    try {
        return JSON.parse(stored) as UserInfo;
    } catch {
        return null;
    }
};

type AuthenticateState = {
    accessToken: string | null;
    refreshToken: string | null;
    user: UserInfo | null;
    setAuthenticate: (data: ResponseAccessData) => void;
    setTokens: (accessToken: string, refreshToken?: string | null) => void;
    clearAuthenticate: () => void;
};

export const useAuthenticateStore = create<AuthenticateState>((set) => ({
    accessToken: readStoredAccessToken(),
    refreshToken: sessionStorage.getItem(REFRESH_TOKEN_KEY),
    user: readStoredUser(),
    // 로그인 성공 — 토큰과 유저를 한 번에 세운다
    setAuthenticate: ({ access_token, refresh_token, user }) => {
        sessionStorage.setItem(ACCESS_TOKEN_KEY, access_token);
        sessionStorage.setItem(REFRESH_TOKEN_KEY, refresh_token);
        sessionStorage.setItem(USER_KEY, JSON.stringify(user));
        set({ accessToken: access_token, refreshToken: refresh_token, user });
    },
    // refresh 로 토큰만 회전 — 서버가 refresh_token 을 새로 주지 않으면 기존 값을 유지한다
    setTokens: (accessToken, refreshToken) => {
        sessionStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
        if (refreshToken) sessionStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);

        set((state) => ({
            accessToken,
            refreshToken: refreshToken ?? state.refreshToken,
        }));
    },
    clearAuthenticate: () => {
        sessionStorage.removeItem(ACCESS_TOKEN_KEY);
        sessionStorage.removeItem(REFRESH_TOKEN_KEY);
        sessionStorage.removeItem(USER_KEY);
        set({ accessToken: null, refreshToken: null, user: null });
    },
}));
