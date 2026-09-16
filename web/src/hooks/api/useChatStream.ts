import { useState } from "react";
import { openChatStream } from "@/api/chatStream";
import { getChatMessages } from "@/service/chat";
import { useChatSessionStore } from "@/store/chatSession";

export type ChatViewMessage = {
    key: string;
    role: "user" | "assistant";
    content: string;
    cards: ChatCard[];
    sourceNote: string | null;
};

export type ChatStreamState = {
    sessionId: string | null;
    messages: ChatViewMessage[];
    streamingText: string;
    streamingCards: ChatCard[];
    streamingSourceNote: string | null;
    statusLabel: string | null;
    isStreaming: boolean;
    errorMessage: string | null;
};

const INITIAL_CHAT_STREAM: ChatStreamState = {
    sessionId: null,
    messages: [],
    streamingText: "",
    streamingCards: [],
    streamingSourceNote: null,
    statusLabel: null,
    isStreaming: false,
    errorMessage: null,
};

const useChatStream = () => {
    const [chat, setChat] = useState<ChatStreamState>(INITIAL_CHAT_STREAM);
    const refreshSessions = useChatSessionStore((state) => state.refreshSessions);

    // 새 대화 시작 (사이드바의 "새 대화")
    const resetChat = () => setChat(INITIAL_CHAT_STREAM);

    // 과거 세션 복원 — assistant 메시지의 tool_trace 로 카드까지 되살린다
    const loadSession = async (sessionId: string) => {
        try {
            const res = await getChatMessages(sessionId);

            setChat({
                ...INITIAL_CHAT_STREAM,
                sessionId,
                messages: res.data.items.map((message) => ({
                    key: String(message.id),
                    role: message.role,
                    content: message.content,
                    cards: message.tool_trace,
                    sourceNote: null,
                })),
            });
        } catch (e) {
            console.error(e);
            setChat({ ...INITIAL_CHAT_STREAM, sessionId, errorMessage: "대화를 불러오지 못했습니다." });
        }
    };

    const applyStreamEvent = (streamEvent: ChatStreamEvent) => {
        setChat((prev) => {
            switch (streamEvent.event) {
                case "meta":
                    return { ...prev, sessionId: streamEvent.data.session_id };
                case "status":
                    return { ...prev, statusLabel: streamEvent.data.label };
                case "card":
                    return { ...prev, streamingCards: [...prev.streamingCards, streamEvent.data] };
                case "delta":
                    return { ...prev, streamingText: prev.streamingText + streamEvent.data.text };
                case "sources":
                    return { ...prev, streamingSourceNote: streamEvent.data.note };
                // final 은 delta 누적 결과와 같지만, 누락된 조각이 있어도 여기서 확정된다
                case "final":
                    return { ...prev, streamingText: streamEvent.data.text };
                case "done":
                    return {
                        ...prev,
                        messages: [
                            ...prev.messages,
                            {
                                key: streamEvent.data.message_id,
                                role: "assistant",
                                content: prev.streamingText,
                                cards: prev.streamingCards,
                                sourceNote: prev.streamingSourceNote,
                            },
                        ],
                        streamingText: "",
                        streamingCards: [],
                        streamingSourceNote: null,
                        statusLabel: null,
                        isStreaming: false,
                    };
                case "error":
                    return {
                        ...prev,
                        statusLabel: null,
                        isStreaming: false,
                        errorMessage: streamEvent.data.message,
                    };
                default:
                    return prev;
            }
        });
    };

    const sendMessage = async (message: string) => {
        const trimmed = message.trim();
        // 생성 중에 다시 보내면 서버가 CHAT_BUSY 로 거절하고 메시지도 저장되지 않는다
        if (!trimmed || chat.isStreaming) return;

        setChat((prev) => ({
            ...prev,
            messages: [
                ...prev.messages,
                { key: `user-${Date.now()}`, role: "user", content: trimmed, cards: [], sourceNote: null },
            ],
            streamingText: "",
            streamingCards: [],
            streamingSourceNote: null,
            statusLabel: null,
            isStreaming: true,
            errorMessage: null,
        }));

        try {
            await openChatStream(
                { message: trimmed, session_id: chat.sessionId },
                { onEvent: applyStreamEvent },
            );
            // 제목은 첫 질문으로 서버가 생성하므로 답변이 끝난 뒤 목록을 다시 받는다
            await refreshSessions();
        } catch (e) {
            console.error(e);
            setChat((prev) => ({
                ...prev,
                statusLabel: null,
                isStreaming: false,
                errorMessage: e instanceof Error ? e.message : "대화 중 오류가 발생했습니다.",
            }));
        }
    };

    return { chat, sendMessage, loadSession, resetChat };
};
export default useChatStream;
