declare global {
    type ResponseSuccessData<TData> = {
        success: boolean;
        code: "OK";
        message?: string | null;
        retriable: boolean;
        timestamp: string;
        data: TData;
    };
};