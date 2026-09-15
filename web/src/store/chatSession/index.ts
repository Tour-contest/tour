import { create } from "zustand";
import { getChatSessions } from "@/service/chat";

// 사이드바(목록 표시)와 챗봇 화면(답변 완료 후 갱신)이 같은 목록을 봐야 해서 store 로 공유한다.
// 제목은 첫 질문으로 서버가 만들기 때문에 done 이후 재조회가 필요하다
type ChatSessionState = {
    sessions: ChatSession[];
    refreshSessions: () => Promise<void>;
};

export const useChatSessionStore = create<ChatSessionState>((set) => ({
    sessions: [],
    refreshSessions: async () => {
        try {
            const res = await getChatSessions();
            set({ sessions: res.data.items });
        } catch (e) {
            console.error(e);
        }
    },
}));
