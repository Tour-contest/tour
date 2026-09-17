import { create } from "zustand";
import { openChatStream, resumeChatStream } from "@/api/chatStream";
import { getChatMessages } from "@/service/chat";
import { useChatSessionStore } from "@/store/chatSession";

// 서버 id 를 받기 전 새 대화가 머무는 임시 칸. meta 로 id 가 오면 그 id 칸으로 옮겨진다
export const NEW_CONVERSATION_KEY = "new";

// 이력은 최신 묶음부터 받고, 위로 스크롤할 때 before 커서로 그 이전 묶음을 이어 붙인다 (명세 1~200, 기본 100)
export const HISTORY_PAGE_SIZE = 50;
// 서버가 빨라도 스피너가 잠깐은 보이게 해서 이전 묶음이 갑자기 튀어나오지 않게 한다
export const MIN_OLDER_LOADING_MS = 600;

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export type ChatViewMessage = {
    key: string;
    role: "user" | "assistant";
    content: string;
    cards: ChatCard[];
    sourceNote: string | null;
};

// 생성 중인 답변. 첫 조각이 도착할 때 만들어져 done 에서 메시지로 확정된다
type StreamingDraft = {
    text: string;
    cards: ChatCard[];
    sourceNote: string | null;
};

export type Conversation = {
    messages: ChatViewMessage[];
    draft: StreamingDraft | null;
    statusLabel: string | null;
    isStreaming: boolean;
    isHistoryLoaded: boolean;
    // 더 오래된 묶음을 받을 때 넘길 커서. 서버가 next_before 로 알려주며 더 없으면 null (명세)
    nextBefore: number | null;
    hasMoreHistory: boolean;
    isLoadingOlder: boolean;
    errorMessage: string | null;
};

export const EMPTY_CONVERSATION: Conversation = {
    messages: [],
    draft: null,
    statusLabel: null,
    isStreaming: false,
    isHistoryLoaded: false,
    nextBefore: null,
    hasMoreHistory: false,
    isLoadingOlder: false,
    errorMessage: null,
};

const toViewMessage = (message: ChatMessage): ChatViewMessage => ({
    key: String(message.id),
    role: message.role,
    content: message.content,
    cards: message.tool_trace,
    sourceNote: null,
});

const EMPTY_DRAFT: StreamingDraft = {
    text: "",
    cards: [],
    sourceNote: null,
};

// 대화마다 열려 있는 연결. 렌더와 무관한 값이라 store 상태에 두지 않는다
const activeStreams = new Map<string, AbortController>();
const loadingHistory = new Set<string>();
// 로그아웃 뒤 늦게 도착한 이력 응답이 다음 사용자의 store 를 채우지 않도록 세대를 구분한다
let sessionEpoch = 0;

// 받은 내용이 없으면(진행 중 답변이 없던 이어받기의 done) 메시지를 만들지 않는다
const commitDraft = (conversation: Conversation, messageKey: string): ChatViewMessage[] => {
    const { draft } = conversation;
    if (!draft || (!draft.text && draft.cards.length === 0)) return conversation.messages;

    return [
        ...conversation.messages,
        { key: messageKey, role: "assistant", content: draft.text, cards: draft.cards, sourceNote: draft.sourceNote },
    ];
};

const reduceStreamEvent = (conversation: Conversation, streamEvent: ChatStreamEvent): Conversation => {
    const draft = conversation.draft ?? EMPTY_DRAFT;

    switch (streamEvent.event) {
        // 이어받기는 전송 없이 붙으므로, 진행 이벤트가 오는 순간 생성 중으로 본다
        case "status":
            return { ...conversation, isStreaming: true, statusLabel: streamEvent.data.label };
        case "tool":
            return { ...conversation, isStreaming: true };
        case "card":
            return { ...conversation, isStreaming: true, draft: { ...draft, cards: [...draft.cards, streamEvent.data] } };
        case "delta":
            return { ...conversation, isStreaming: true, draft: { ...draft, text: draft.text + streamEvent.data.text } };
        case "sources":
            return { ...conversation, draft: { ...draft, sourceNote: streamEvent.data.note } };
        // final 은 delta 누적 결과와 같지만, 누락된 조각이 있어도 여기서 확정된다
        case "final":
            return { ...conversation, draft: { ...draft, text: streamEvent.data.text } };
        case "done":
            return {
                ...conversation,
                messages: commitDraft(conversation, streamEvent.data.message_id),
                draft: null,
                statusLabel: null,
                isStreaming: false,
            };
        // 실패해도 이미 받은 카드·문장은 남긴다
        case "error":
            return {
                ...conversation,
                messages: commitDraft(conversation, `partial-${Date.now()}`),
                draft: null,
                statusLabel: null,
                isStreaming: false,
                errorMessage: streamEvent.data.message,
            };
        default:
            return conversation;
    }
};

type StreamOpener = (signal: AbortSignal, onEvent: (streamEvent: ChatStreamEvent) => void) => Promise<void>;

type ChatState = {
    conversations: Record<string, Conversation>;
    // 새 대화가 방금 서버 id 를 받았다는 신호. 화면이 URL 을 교체한 뒤 비운다
    promotedSessionId: string | null;
    sendMessage: (key: string, message: string) => Promise<void>;
    openConversation: (sessionId: string) => Promise<void>;
    loadOlderMessages: (sessionId: string) => Promise<void>;
    prepareNewConversation: () => void;
    clearPromotedSession: () => void;
    removeConversation: (sessionId: string) => void;
    clearConversations: () => void;
};

export const useChatStore = create<ChatState>((set, get) => {
    const patchConversation = (key: string, update: (conversation: Conversation) => Conversation) => {
        set((state) => ({
            conversations: {
                ...state.conversations,
                [key]: update(state.conversations[key] ?? EMPTY_CONVERSATION),
            },
        }));
    };

    // 임시 칸을 서버 id 칸으로 옮긴다. 화면은 같은 내용을 계속 읽으므로 이력을 다시 부르지 않는다
    const promoteNewConversation = (sessionId: string, controller: AbortController) => {
        set((state) => {
            const { [NEW_CONVERSATION_KEY]: pending, ...rest } = state.conversations;

            return {
                conversations: {
                    ...rest,
                    // 새 대화는 로컬에 전체 대화가 있으므로 이력이 로드된 것으로 본다
                    [sessionId]: { ...(pending ?? EMPTY_CONVERSATION), isHistoryLoaded: true },
                },
                promotedSessionId: sessionId,
            };
        });

        activeStreams.delete(NEW_CONVERSATION_KEY);
        activeStreams.set(sessionId, controller);

        // 제목은 첫 질문으로 서버가 만들어 meta 에 실어준다 — 사이드바에 바로 보이게 목록을 갱신한다
        useChatSessionStore.getState().refreshSessions();
    };

    // 전송과 이어받기가 공유하는 연결 수명주기. 이벤트는 자기 대화 칸에만 쌓인다
    const runStream = async (initialKey: string, open: StreamOpener, refreshSessionsOnSettle: boolean) => {
        let key = initialKey;
        let settled = false;
        const controller = new AbortController();
        activeStreams.set(key, controller);

        const onEvent = (streamEvent: ChatStreamEvent) => {
            if (streamEvent.event === "meta") {
                if (key === NEW_CONVERSATION_KEY) {
                    promoteNewConversation(streamEvent.data.session_id, controller);
                    key = streamEvent.data.session_id;
                }
                return;
            }

            if (streamEvent.event === "done" || streamEvent.event === "error") settled = true;
            patchConversation(key, (conversation) => reduceStreamEvent(conversation, streamEvent));
        };

        try {
            await open(controller.signal, onEvent);

            // done·error 없이 끊기면 미완성이다. 서버는 끝까지 생성해 저장하므로,
            // 다음 진입 때 이력을 다시 받고 이어받기로 복원되도록 로드 상태를 되돌린다
            if (!settled) {
                patchConversation(key, (conversation) => ({
                    ...conversation,
                    messages: commitDraft(conversation, `partial-${Date.now()}`),
                    draft: null,
                    statusLabel: null,
                    isStreaming: false,
                    isHistoryLoaded: false,
                    errorMessage: "연결이 끊겼어요. 다시 들어오면 이어서 받을 수 있어요.",
                }));
            }

            if (refreshSessionsOnSettle) useChatSessionStore.getState().refreshSessions();
        } catch (e) {
            // 로그아웃 등으로 의도적으로 끊은 연결은 오류가 아니다
            if (controller.signal.aborted) return;

            console.error(e);
            patchConversation(key, (conversation) => ({
                ...conversation,
                statusLabel: null,
                isStreaming: false,
                errorMessage: e instanceof Error ? e.message : "대화 중 오류가 발생했습니다.",
            }));
        } finally {
            if (activeStreams.get(key) === controller) activeStreams.delete(key);
        }
    };

    return {
        conversations: {},
        promotedSessionId: null,

        sendMessage: async (key, message) => {
            const trimmed = message.trim();
            const current = get().conversations[key] ?? EMPTY_CONVERSATION;

            // 생성 중에 다시 보내면 서버가 CHAT_BUSY 로 거절하고 메시지도 저장되지 않는다
            if (!trimmed || current.isStreaming) return;

            patchConversation(key, (conversation) => ({
                ...conversation,
                messages: [
                    ...conversation.messages,
                    { key: `user-${Date.now()}`, role: "user", content: trimmed, cards: [], sourceNote: null },
                ],
                draft: null,
                statusLabel: null,
                isStreaming: true,
                errorMessage: null,
            }));

            const sessionId = key === NEW_CONVERSATION_KEY ? null : key;

            await runStream(
                key,
                (signal, onEvent) => openChatStream({ message: trimmed, session_id: sessionId }, { onEvent, signal }),
                true,
            );
        },

        openConversation: async (sessionId) => {
            const existing = get().conversations[sessionId];

            // 이미 들고 있거나 생성 중이면 다시 부르지 않는다.
            // URL 교체 · 다른 대화 다녀오기 · StrictMode 의 effect 2회 실행이 전부 여기서 걸러진다
            if (existing?.isStreaming || existing?.isHistoryLoaded || loadingHistory.has(sessionId)) return;

            const epoch = sessionEpoch;
            loadingHistory.add(sessionId);

            try {
                const res = await getChatMessages(sessionId, { limit: HISTORY_PAGE_SIZE });
                if (epoch !== sessionEpoch) return;

                set((state) => ({
                    conversations: {
                        ...state.conversations,
                        [sessionId]: {
                            ...EMPTY_CONVERSATION,
                            isHistoryLoaded: true,
                            messages: res.data.items.map(toViewMessage),
                            nextBefore: res.data.page.next_before,
                            hasMoreHistory: res.data.page.has_more,
                        },
                    },
                }));
            } catch (e) {
                console.error(e);
                if (epoch !== sessionEpoch) return;
                patchConversation(sessionId, () => ({ ...EMPTY_CONVERSATION, errorMessage: "대화를 불러오지 못했습니다." }));
                return;
            } finally {
                loadingHistory.delete(sessionId);
            }

            // 새로고침 등으로 끊긴 답변이 서버에서 아직 생성 중이면 이어받는다
            // TODO: 진행 중인 답변이 이력 응답에도 포함되는지 서버 확인 필요 — 포함된다면 이력과 재생이 중복 표시된다
            if (activeStreams.has(sessionId)) return;

            await runStream(
                sessionId,
                (signal, onEvent) => resumeChatStream(sessionId, { onEvent, signal }),
                false,
            );
        },

        // 위로 스크롤했을 때 더 오래된 묶음을 앞에 이어 붙인다. 커서 방식이라 그 사이 메시지가 늘어도 페이지가 밀리지 않는다
        loadOlderMessages: async (sessionId) => {
            const current = get().conversations[sessionId];
            if (!current?.hasMoreHistory || current.isLoadingOlder || current.nextBefore === null) return;

            const epoch = sessionEpoch;
            const before = current.nextBefore;
            patchConversation(sessionId, (conversation) => ({ ...conversation, isLoadingOlder: true }));

            try {
                const [res] = await Promise.all([
                    getChatMessages(sessionId, { limit: HISTORY_PAGE_SIZE, before }),
                    sleep(MIN_OLDER_LOADING_MS),
                ]);
                if (epoch !== sessionEpoch) return;

                patchConversation(sessionId, (conversation) => {
                    // 같은 메시지가 두 번 오더라도(경계 중복) 한 번만 남긴다
                    const knownKeys = new Set(conversation.messages.map((message) => message.key));
                    const older = res.data.items.map(toViewMessage).filter((message) => !knownKeys.has(message.key));

                    return {
                        ...conversation,
                        messages: [...older, ...conversation.messages],
                        nextBefore: res.data.page.next_before,
                        hasMoreHistory: res.data.page.has_more,
                        isLoadingOlder: false,
                    };
                });
            } catch (e) {
                console.error(e);
                if (epoch !== sessionEpoch) return;
                // 커서는 그대로 둬서 다시 스크롤하면 재시도된다
                patchConversation(sessionId, (conversation) => ({ ...conversation, isLoadingOlder: false }));
            }
        },

        prepareNewConversation: () => {
            // 첫 메시지를 보내고 서버 id 를 기다리는 중이면 그대로 둔다
            if (get().conversations[NEW_CONVERSATION_KEY]?.isStreaming) return;

            set((state) => ({
                conversations: { ...state.conversations, [NEW_CONVERSATION_KEY]: EMPTY_CONVERSATION },
            }));
        },

        clearPromotedSession: () => {
            if (get().promotedSessionId === null) return;
            set({ promotedSessionId: null });
        },

        // 삭제된 대화 — 생성 중이었다면 연결을 끊어야 사라진 칸에 조각이 다시 쌓이지 않는다
        removeConversation: (sessionId) => {
            activeStreams.get(sessionId)?.abort();
            activeStreams.delete(sessionId);

            set((state) => {
                const conversations = { ...state.conversations };
                delete conversations[sessionId];
                return { conversations };
            });
        },

        // 세션 종료 시 연결을 모두 끊고 대화 캐시를 비운다 (공용 PC 에서 다음 사용자에게 남지 않도록)
        clearConversations: () => {
            sessionEpoch += 1;
            activeStreams.forEach((controller) => controller.abort());
            activeStreams.clear();
            loadingHistory.clear();
            set({ conversations: {}, promotedSessionId: null });
        },
    };
});
