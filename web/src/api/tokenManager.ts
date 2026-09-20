import { requestRefresh as requestRefreshApi } from "@/service/auth";
import { useAuthenticateStore } from "@/store/authenticate";
import { useAuthorityStore } from "@/store/authority";
import { useChatStore } from "@/store/chat";
import { useChatSessionStore } from "@/store/chatSession";
import { jwtDecoder } from "@/utils";

// 만료 10초 전부터 만료로 취급 — 전송 중 만료되는 경계 케이스 방지 여유마진
const EXPIRY_MARGIN_MS = 10_000;

export const isTokenExpired = (token: string) => {
    const payload = jwtDecoder<AccessTokenPayload>(token);
    if (!payload?.exp) return true;   // 디코딩 불가/exp 없음 → 만료 취급 (refresh 로 복구 시도)

    return payload.exp * 1000 <= Date.now() + EXPIRY_MARGIN_MS;
};

// 동시에 여러 요청이 만료를 감지해도 refresh 는 한 번만 — 진행 중인 Promise 를 전원이 공유(single-flight)
// rotation 서버에서 refresh_token 을 중복 사용하면 재사용 거부로 억울한 로그아웃이 난다
let refreshPromise: Promise<ResponseAutenticate> | null = null;

export const requestRefresh = () => {
    if (!refreshPromise) {
        const refreshToken = useAuthenticateStore.getState().refreshToken ?? "";

        refreshPromise = requestRefreshApi(refreshToken)
            .finally(() => { refreshPromise = null; });
    }
    return refreshPromise;
};

// refresh 로 받은 새 토큰 반영 — 선제 refresh 와 401 사후 refresh 가 공용으로 사용
export const applyRefreshedToken = ({ access_token, refresh_token }: ResponseAccessData) => {
    useAuthenticateStore.getState().setTokens(access_token, refresh_token);
    useAuthorityStore.getState().setAuthority(access_token);
};

// 세션 종료 처리 (refresh 실패/세션 만료/로그인 화면 진입) — 인증/권한 store 를 함께 초기화.
// 대화 캐시도 사용자 단위라 같이 비운다 (SPA 이동이라 메모리가 남아 다음 로그인 사용자에게 보일 수 있다)
export const clearSession = () => {
    useAuthenticateStore.getState().clearAuthenticate();
    useAuthorityStore.getState().clearAuthority();
    useChatStore.getState().clearConversations();
    useChatSessionStore.getState().clearSessions();
};
