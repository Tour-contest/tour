// 카카오 인가 코드 흐름의 주소 (순수 함수 · 상수)

const KAKAO_AUTHORIZE_URL = "https://kauth.kakao.com/oauth/authorize";

// 카카오 디벨로퍼스 콘솔에 등록된 Redirect URI 와 정확히 같아야 한다 (호스트가 window.location.origin 과 다를 수 있어 env 로 고정).
// 인가 요청과 콜백 교환 양쪽이 같은 값을 써야 하므로 한 곳에서만 읽는다
export const KAKAO_REDIRECT_URI: string = import.meta.env.VITE_KAKAO_REDIRECT_URI;

export const buildKakaoAuthorizeUrl = (clientId: string) => {
    const url = new URL(KAKAO_AUTHORIZE_URL);
    url.searchParams.set("client_id", clientId);
    url.searchParams.set("redirect_uri", KAKAO_REDIRECT_URI);
    url.searchParams.set("response_type", "code");
    return url.toString();
};
