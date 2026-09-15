declare global {
    type GetUserParams = {
        q?: string;
        limit?: number;
        offset?: string | undefined;
    };

    type MyInfo = {
        id: string;
        nickname: string;
        role: "admin" | "user";
        provider: "kakao";
        created_at: string;
    };

    type ResponseMyInfo = ResponseSuccessData<MyInfo>;
}