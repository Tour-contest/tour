import { requestModule } from "@/api/requestModule";

const getChatSessions = (params?: RequestChatSessionsParams) => {
    return requestModule.get<ResponseChatSessions>('/api/v1/chat/sessions', params);
};

const getChatMessages = (session_id: string, params?: RequestChatMessagesParams) => {
    return requestModule.get<ResponseChatMessages>(`/api/v1/chat/sessions/${session_id}/messages`, params);
};

const deleteChatSession = (session_id: string) => {
    return requestModule.delete<ResponseProcess>(`/api/v1/chat/sessions/${session_id}`);
};

// POST /chat/stream 과 GET /chat/sessions/{id}/stream 은 SSE 라 axios 를 타지 않는다 (fetch + ReadableStream)
export {
    getChatSessions,
    getChatMessages,
    deleteChatSession
};
