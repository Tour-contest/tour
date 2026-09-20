import { jwtDecode } from "jwt-decode";

// 디코딩 실패를 예외가 아닌 null 로 흘려보낸다 — 호출부가 "복호화 불가 = 신뢰할 수 없는 토큰"으로 일관되게 처리하도록
const jwtDecoder = <T>(token: string | null): T | null => {
    if (!token) return null;

    try {
        return jwtDecode<T>(token);
    } catch (e) {
        console.error("token decode 실패", e);
        return null;
    }
};
export default jwtDecoder;
