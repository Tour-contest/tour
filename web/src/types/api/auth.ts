declare global {
    type UserRole = "admin" | "user";

    type UserInfo = {
        id: string;
        nickname: string | null;
        role: UserRole;
        provider: "kakao" | "local" | "dev"
    };

    type ResponseAccessData = {
        access_token: string;
        refresh_token: string;
        expires_in: number;
        user: UserInfo;
    };

    type SocialInfo = {
        provider: "kakao";
        client_id: string;
    };

    type ResponseProviderData = {
        social: SocialInfo[];
        dev_login: boolean;
    };

    type ResponseSuccessLogout = {
        ok: boolean;
    };

    type ResponseAutenticate = ResponseSuccessData<ResponseAccessData>;

    type ResponseAutenticateProvider = ResponseSuccessData<ResponseProviderData>;

    type ResponseLogout = ResponseSuccessData<ResponseSuccessLogout>;

    // access_token 페이로드 실측 기준 (개발자 로그인 admin / 카카오 로그인 user 양쪽 확인)
    type AccessTokenPayload = {
        sub: string;
        role: UserRole;
        typ: "access";
        iat: number;
        exp: number;
    };
};