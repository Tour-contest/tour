import { create } from "zustand";
import { getChatSessions } from "@/service/chat";

// 명세 기본값. 목록은 최근 활동순이고 has_more 면 offset 을 늘려 이어 받는다 (limit 최대 100)
export const SESSION_PAGE_SIZE = 30;
const SESSION_LIMIT_MAX = 100;

// 사이드바(목록 표시)와 챗봇 화면(답변 완료 후 갱신)이 같은 목록을 봐야 해서 store 로 공유한다.
// 제목은 첫 질문으로 서버가 만들기 때문에 done 이후 재조회가 필요하다
type ChatSessionState = {
    sessions: ChatSession[];
    hasMore: boolean;
    isLoadingMore: boolean;
    refreshSessions: () => Promise<void>;
    loadMoreSessions: () => Promise<void>;
    clearSessions: () => void;
};

export const useChatSessionStore = create<ChatSessionState>((set, get) => ({
    sessions: [],
    hasMore: false,
    isLoadingMore: false,

    // 더 보기로 늘어난 만큼은 유지한 채 처음부터 다시 받는다 — 기본 30건으로 돌아가면 목록이 갑자기 줄어든다
    refreshSessions: async () => {
        const limit = Math.min(Math.max(SESSION_PAGE_SIZE, get().sessions.length), SESSION_LIMIT_MAX);

        try {
            const res = await getChatSessions({ limit, offset: 0 });
            set({ sessions: res.data.items, hasMore: res.data.page.has_more });
        } catch (e) {
            console.error(e);
        }
    },

    loadMoreSessions: async () => {
        const { sessions, hasMore, isLoadingMore } = get();
        if (!hasMore || isLoadingMore) return;

        set({ isLoadingMore: true });
        try {
            const res = await getChatSessions({ limit: SESSION_PAGE_SIZE, offset: sessions.length });
            // 그 사이 새 대화가 생겨 offset 이 밀리면 같은 세션이 한 번 더 올 수 있다 — id 로 거른다
            const knownIds = new Set(sessions.map((session) => session.id));
            const added = res.data.items.filter((session) => !knownIds.has(session.id));

            set((state) => ({
                sessions: [...state.sessions, ...added],
                hasMore: res.data.page.has_more,
                isLoadingMore: false,
            }));
        } catch (e) {
            console.error(e);
            set({ isLoadingMore: false });
        }
    },

    clearSessions: () => set({ sessions: [], hasMore: false, isLoadingMore: false }),
}));
