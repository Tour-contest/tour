declare global {
    type UserInfo = {
        id: string;
        nickname: string;
        role: "admin" | "user";
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

    type ResponseAutenticate = ResponseSuccessData<ResponseAccessData>;

    type ResponseAutenticateProvider = ResponseSuccessData<ResponseProviderData>;
};