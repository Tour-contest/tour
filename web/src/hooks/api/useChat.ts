import { isAxiosError } from "axios";
import {
    getChatSessions,
    getChatMessages,
    deleteChatSession
} from "@/service/chat";

const useChat = () => {
    const fetchChatSessions = async (params?: RequestChatSessionsParams) => {
        try {
            const res = await getChatSessions(params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const fetchChatMessages = async (sessionId: string, params?: RequestChatMessagesParams) => {
        try {
            const res = await getChatMessages(sessionId, params);
            return res.data;
        } catch (e) {
            console.error(e);
            return null;
        };
    };

    const handleDeleteChatSession = async (sessionId: string) => {
        try {
            const res = await deleteChatSession(sessionId);
            return res.data.ok;
        } catch (e) {
            // 이미 없는 대화(404)는 목록에서만 지우면 된다 (명세)
            if (isAxiosError(e) && e.response?.status === 404) return true;
            console.error(e);
            return false;
        };
    };

    return {
        fetchChatSessions,
        fetchChatMessages,
        handleDeleteChatSession
    };
};
export default useChat;
