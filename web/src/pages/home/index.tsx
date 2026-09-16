import { useEffect, useRef } from "react";
import { useNavigate, useParams } from "react-router";
import clsx from "clsx";
import { useChatStore, EMPTY_CONVERSATION, NEW_CONVERSATION_KEY } from "@/store/chat";
import ChatbotAgenda from "./ChatbotAgenda";
import ChatbotMessages from "./ChatbotMessages";
import ChatbotStreaming from "./ChatbotStreaming";
import ChatbotInput from "./ChatbotInput";

const ATTRIBUTION = "출처: ⓒ한국관광공사";

// 대화 상태는 store 가 대화 id 단위로 들고 있고, 화면은 URL 의 대화 칸을 읽기만 한다.
// 다른 대화로 이동해도 진행 중인 답변은 자기 칸에서 계속 쌓이고, 돌아오면 이어서 보인다
function Home() {
    const navigate = useNavigate();
    // 세션은 URL 이 소유한다 — 사이드바에서 고른 대화(/c/:sessionId), 없으면 새 대화(/)
    const { sessionId } = useParams<{ sessionId: string }>();

    const promotedSessionId = useChatStore((state) => state.promotedSessionId);
    const sendMessage = useChatStore((state) => state.sendMessage);
    const openConversation = useChatStore((state) => state.openConversation);
    const prepareNewConversation = useChatStore((state) => state.prepareNewConversation);
    const clearPromotedSession = useChatStore((state) => state.clearPromotedSession);

    // 새 대화가 방금 서버 id 를 받았다면 URL 이 바뀌기 전 한 프레임도 옮겨간 칸을 읽는다 (빈 화면 깜빡임 방지)
    const activeKey = sessionId ?? promotedSessionId ?? NEW_CONVERSATION_KEY;
    const conversation = useChatStore((state) => state.conversations[activeKey]) ?? EMPTY_CONVERSATION;

    const scrollAnchorRef = useRef<HTMLDivElement | null>(null);

    // store 액션은 참조가 고정이라 의존성에 넣어도 sessionId 가 바뀔 때만 실행된다
    useEffect(() => {
        if (sessionId) openConversation(sessionId);
        else prepareNewConversation();
    }, [sessionId, openConversation, prepareNewConversation]);

    // 새 대화가 서버 id 를 받으면 주소만 교체한다 — 같은 칸을 계속 읽으므로 이력을 다시 부르지 않는다
    useEffect(() => {
        if (sessionId) {
            clearPromotedSession();
            return;
        }
        if (promotedSessionId) navigate(`/c/${promotedSessionId}`, { replace: true });
    }, [sessionId, promotedSessionId, clearPromotedSession, navigate]);

    useEffect(() => {
        scrollAnchorRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [conversation.messages, conversation.draft]);

    const handleSendMessage = (message: string) => {
        sendMessage(activeKey, message);
    };

    const isEmptyChat = conversation.messages.length === 0 && !conversation.isStreaming;

    return (
        <div className={ChatbotContainer}>
            <div className={ChatbotLayout}>
                {isEmptyChat && <ChatbotAgenda onQuickStart={handleSendMessage} />}
                <ChatbotMessages
                    chatMessage={conversation.messages}
                    onSendMessage={handleSendMessage}
                    isSendDisabled={conversation.isStreaming}
                />
                {conversation.isStreaming && (
                    <ChatbotStreaming
                        streamingCards={conversation.draft?.cards ?? []}
                        statusLabel={conversation.statusLabel}
                        streamingText={conversation.draft?.text ?? ""}
                    />
                )}
                {conversation.errorMessage && <p className={ErrorMessage}>{conversation.errorMessage}</p>}
                <div ref={scrollAnchorRef} />
            </div>
            <ChatbotInput isStreaming={conversation.isStreaming} onSubmit={handleSendMessage} />
            <p className={Attribution}>{ATTRIBUTION}</p>
        </div>
    );
}
export default Home;
//style configuration
const ChatbotContainer = clsx(
    "flex flex-col items-center",
    "h-full"
);

const ChatbotLayout = clsx(
    "flex flex-col gap-4 flex-1",
    "w-180 max-w-full",
    "overflow-y-auto",
    "p-6 box-border"
);

const ErrorMessage = clsx(
    "text-[13px] text-[#ff3b30]"
);

const Attribution = clsx(
    "pb-4",
    "text-[12px] text-[#6b6375]"
);
