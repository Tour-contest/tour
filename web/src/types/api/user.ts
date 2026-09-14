declare global {
    type GetUserParams = {
        q?: string;
        limit?: number;
        offset?: string | undefined;
    };
}