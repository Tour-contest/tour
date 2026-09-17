import { useEffect, useLayoutEffect, useRef } from "react";
import { useNavigate, useParams } from "react-router";
import clsx from "clsx";
import { LoadingIndicator } from "@/components/common";
import { useChatStore, EMPTY_CONVERSATION, NEW_CONVERSATION_KEY } from "@/store/chat";
import { useSystemStore } from "@/store/system";
import ChatbotAgenda from "./ChatbotAgenda";
import ChatbotError from "./ChatbotError";
import ChatbotHistoryLoader from "./ChatbotHistoryLoader";
import ChatbotMessages from "./ChatbotMessages";
import ChatbotServiceNotice from "./ChatbotServiceNotice";
import ChatbotStreaming from "./ChatbotStreaming";
import ChatbotInput from "./ChatbotInput";

const ATTRIBUTION = "출처: ⓒ한국관광공사";
// 이 거리 안까지 위로 올리면 이전 묶음을 받는다
const LOAD_OLDER_THRESHOLD_PX = 80;

// 대화 상태는 store 가 대화 id 단위로 들고 있고, 화면은 URL 의 대화 칸을 읽기만 한다.
// 다른 대화로 이동해도 진행 중인 답변은 자기 칸에서 계속 쌓이고, 돌아오면 이어서 보인다
function Home() {
    const navigate = useNavigate();
    // 세션은 URL 이 소유한다 — 사이드바에서 고른 대화(/c/:sessionId), 없으면 새 대화(/)
    const { sessionId } = useParams<{ sessionId: string }>();

    const promotedSessionId = useChatStore((state) => state.promotedSessionId);
    const sendMessage = useChatStore((state) => state.sendMessage);
    const retryLastMessage = useChatStore((state) => state.retryLastMessage);
    const openConversation = useChatStore((state) => state.openConversation);
    const loadOlderMessages = useChatStore((state) => state.loadOlderMessages);
    const prepareNewConversation = useChatStore((state) => state.prepareNewConversation);
    const clearPromotedSession = useChatStore((state) => state.clearPromotedSession);
    const loadReady = useSystemStore((state) => state.loadReady);

    // 첫 화면의 기능 활성 안내용. 페이지 로드당 한 번만 실제 요청이 나간다
    useEffect(() => {
        loadReady();
    }, [loadReady]);

    // 새 대화가 방금 서버 id 를 받았다면 URL 이 바뀌기 전 한 프레임도 옮겨간 칸을 읽는다 (빈 화면 깜빡임 방지)
    const activeKey = sessionId ?? promotedSessionId ?? NEW_CONVERSATION_KEY;
    const conversation = useChatStore((state) => state.conversations[activeKey]) ?? EMPTY_CONVERSATION;

    const scrollContainerRef = useRef<HTMLDivElement | null>(null);
    const scrollAnchorRef = useRef<HTMLDivElement | null>(null);
    // 이전 묶음을 앞에 붙이기 직전의 스크롤 높이. 붙인 뒤 그만큼 내려서 보던 자리를 유지한다
    const pendingScrollHeightRef = useRef<number | null>(null);
    const lastScrollTopRef = useRef<number>(0);

    // store 액션은 참조가 고정이라 의존성에 넣어도 sessionId 가 바뀔 때만 실행된다
    useEffect(() => {
        pendingScrollHeightRef.current = null;
        lastScrollTopRef.current = 0;

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

    // 이전 묶음이 앞에 붙으면 내용이 아래로 밀리므로, 늘어난 높이만큼 스크롤을 내려 보던 위치를 고정한다.
    // 그리기 직후 페인트 전에 맞춰야 화면이 튀지 않는다
    useLayoutEffect(() => {
        const container = scrollContainerRef.current;
        const previousHeight = pendingScrollHeightRef.current;
        if (!container || previousHeight === null) return;

        container.scrollTop += container.scrollHeight - previousHeight;
        pendingScrollHeightRef.current = null;
    }, [conversation.messages]);

    // 맨 아래로 따라가는 건 새 내용이 아래에 생겼을 때만이다. 위에 이전 묶음이 붙을 때는 마지막 메시지가 그대로라 움직이지 않는다
    const lastMessageKey = conversation.messages.at(-1)?.key;

    useEffect(() => {
        scrollAnchorRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [lastMessageKey, conversation.draft]);

    const requestOlderMessages = () => {
        if (!sessionId || !conversation.hasMoreHistory || conversation.isLoadingOlder) return;

        pendingScrollHeightRef.current = scrollContainerRef.current?.scrollHeight ?? null;
        loadOlderMessages(sessionId);
    };

    // 위로 올리는 중에 맨 위 근처에 닿으면 이전 묶음을 받는다.
    // 아래로 내려가는 스크롤(맨 아래 따라가기 · 위치 보정)에는 반응하지 않아야 열자마자 이전 묶음이 불려오지 않는다
    const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
        const { scrollTop } = e.currentTarget;
        const isScrollingUp = scrollTop < lastScrollTopRef.current;
        lastScrollTopRef.current = scrollTop;

        if (isScrollingUp && scrollTop <= LOAD_OLDER_THRESHOLD_PX) requestOlderMessages();
    };

    const handleSendMessage = (message: string) => {
        sendMessage(activeKey, message);
    };

    // 기존 대화를 여는 동안은 아직 메시지가 없어도 빈 대화가 아니다 — 여기서 Quick Start 를 보여주면 서버가 느릴 때 화면이 번쩍 바뀐다
    const isOpeningConversation = !!sessionId && !conversation.isHistoryLoaded
        && conversation.messages.length === 0 && !conversation.errorMessage;
    const isEmptyChat = !isOpeningConversation && conversation.messages.length === 0 && !conversation.isStreaming;
    // 재시도는 답을 못 받은 전송이 남아 있고 서버가 재시도를 허용했을 때만
    const canRetry = conversation.isRetriable && conversation.pendingSend !== null && !conversation.isStreaming;

    return (
        <div className={ChatbotContainer}>
            <ChatbotServiceNotice />
            <div ref={scrollContainerRef} onScroll={handleScroll} className={ChatbotLayout}>
                <ChatbotHistoryLoader
                    hasMore={conversation.hasMoreHistory}
                    isLoading={conversation.isLoadingOlder}
                    onLoadOlder={requestOlderMessages}
                />
                {isOpeningConversation && (
                    <div className={CenterNote}>
                        <LoadingIndicator label="대화를 불러오는 중…" />
                    </div>
                )}
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
                {conversation.errorMessage && (
                    <ChatbotError
                        message={conversation.errorMessage}
                        canRetry={canRetry}
                        onRetry={() => retryLastMessage(activeKey)}
                    />
                )}
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

const CenterNote = clsx(
    "flex flex-1 items-center justify-center"
);

const Attribution = clsx(
    "pb-4",
    "text-[12px] text-[#6b6375]"
);
