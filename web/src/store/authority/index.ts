import { create } from "zustand";
import { readStoredAccessToken } from "@/store/authenticate";
import { jwtDecoder } from "@/utils";

// JWT payload 는 공개 정보라 클라이언트 디코딩은 화면 분기(UX)용으로만 쓴다 — 인가의 최종 판단은 서버
const decodeRole = (accessToken: string | null): UserRole | null => {
    return jwtDecoder<AccessTokenPayload>(accessToken)?.role ?? null;
};

type AuthorityState = {
    role: UserRole | null;
    setAuthority: (accessToken: string) => void;
    clearAuthority: () => void;
};

export const useAuthorityStore = create<AuthorityState>((set) => ({
    role: decodeRole(readStoredAccessToken()),
    setAuthority: (accessToken) => set({ role: decodeRole(accessToken) }),
    clearAuthority: () => set({ role: null }),
}));
