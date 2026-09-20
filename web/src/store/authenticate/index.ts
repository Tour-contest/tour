import { create } from "zustand";

const ACCESS_TOKEN_KEY = "accessToken";
const REFRESH_TOKEN_KEY = "refreshToken";
// 예전 버전이 유저 정보를 저장하던 키. 이제는 저장하지 않고, 남아 있는 값만 지운다
const LEGACY_USER_KEY = "user";

// authority store / tokenManager 가 새로고침 직후 토큰을 복원할 때도 같은 키를 쓰도록 여기서 노출한다
export const readStoredAccessToken = () => sessionStorage.getItem(ACCESS_TOKEN_KEY);

// 유저 정보(닉네임 · 제공자 등)는 브라우저 저장소에 두지 않는다 — 메모리에만 들고, 새로고침으로 비면 내 정보 API 로 다시 채운다 (useCurrentUser)
sessionStorage.removeItem(LEGACY_USER_KEY);

type AuthenticateState = {
    accessToken: string | null;
    refreshToken: string | null;
    user: UserInfo | null;
    setAuthenticate: (data: ResponseAccessData) => void;
    setUser: (user: UserInfo) => void;
    setTokens: (accessToken: string, refreshToken?: string | null) => void;
    clearAuthenticate: () => void;
};

export const useAuthenticateStore = create<AuthenticateState>((set) => ({
    accessToken: readStoredAccessToken(),
    refreshToken: sessionStorage.getItem(REFRESH_TOKEN_KEY),
    user: null,
    // 로그인 성공 — 토큰과 유저를 한 번에 세운다
    setAuthenticate: ({ access_token, refresh_token, user }) => {
        sessionStorage.setItem(ACCESS_TOKEN_KEY, access_token);
        sessionStorage.setItem(REFRESH_TOKEN_KEY, refresh_token);
        set({ accessToken: access_token, refreshToken: refresh_token, user });
    },
    // 새로고침 뒤 내 정보 API 로 받은 값을 메모리에만 싣는다
    setUser: (user) => set({ user }),
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
        sessionStorage.removeItem(LEGACY_USER_KEY);
        set({ accessToken: null, refreshToken: null, user: null });
    },
}));
