import { useEffect } from "react";
import clsx from "clsx";
import { LogoLoading } from "@/components/common";
import { useChatStore } from "@/store/chat";
import { useSystemStore } from "@/store/system";
import useChatScroll from "./hooks/useChatScroll";
import useConversationRoute from "./hooks/useConversationRoute";
import ChatbotAgenda from "./ChatbotAgenda";
import ChatbotError from "./ChatbotError";
import ChatbotHistoryLoader from "./ChatbotHistoryLoader";
import ChatbotMessages from "./ChatbotMessages";
import ChatbotServiceNotice from "./ChatbotServiceNotice";
import ChatbotStreaming from "./ChatbotStreaming";
import ChatbotInput from "./ChatbotInput";

// 대화 상태는 store 가 대화 id 단위로 들고 있고, 화면은 URL 의 대화 칸을 읽기만 한다.
// 다른 대화로 이동해도 진행 중인 답변은 자기 칸에서 계속 쌓이고, 돌아오면 이어서 보인다
function Home() {
    // URL 이 소유한 대화 칸 (새 대화 id 승격 · 이력 열기 포함)
    const { sessionId, activeKey, conversation } = useConversationRoute();

    const sendMessage = useChatStore((state) => state.sendMessage);
    const retryLastMessage = useChatStore((state) => state.retryLastMessage);
    const loadOlderMessages = useChatStore((state) => state.loadOlderMessages);
    const loadReady = useSystemStore((state) => state.loadReady);

    // 첫 화면의 기능 활성 안내용. 페이지 로드당 한 번만 실제 요청이 나간다
    useEffect(() => {
        loadReady();
    }, [loadReady]);

    // 위로 스크롤 시 이전 묶음 · 붙은 높이만큼 위치 보정 · 새 내용(마지막 메시지 · 생성 중 초안)이면 맨 아래 따라가기
    const { scrollContainerRef, scrollAnchorRef, handleScroll, requestOlderMessages } = useChatScroll({
        conversationKey: sessionId,
        messages: conversation.messages,
        // 생각 중 로고는 첫 status 이벤트가 와야 그려지므로 진행 문구 · 스트리밍 여부도 기준에 넣어 그때도 맨 아래로 따라간다
        bottomFollowKey: `${conversation.messages.at(-1)?.key}|${conversation.isStreaming}|${conversation.statusLabel ?? ""}|${conversation.draft?.text ?? ""}|${conversation.draft?.cards.length ?? 0}`,
        canLoadOlder: !!sessionId && conversation.hasMoreHistory && !conversation.isLoadingOlder,
        onLoadOlder: () => { if (sessionId) loadOlderMessages(sessionId); },
    });

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
            {/* 스크롤 영역은 본문 전체 폭이라 스크롤바가 오른쪽 끝에 붙고, 내용만 가운데 720px 로 모은다 */}
            <div ref={scrollContainerRef} onScroll={handleScroll} className={ChatbotScroller}>
                <div className={ChatbotLayout}>
                <ChatbotHistoryLoader
                    hasMore={conversation.hasMoreHistory}
                    isLoading={conversation.isLoadingOlder}
                    onLoadOlder={requestOlderMessages}
                />
                {isOpeningConversation && (
                    <div className={CenterNote}>
                        <LogoLoading label="대화를 불러오는 중…" />
                    </div>
                )}
                {/* 새 대화 화면에서는 입력창이 인사말 아래(가운데)에 온다. 대화가 시작되면 아래 고정 입력창으로 */}
                {isEmptyChat && (
                    <ChatbotAgenda
                        onQuickStart={handleSendMessage}
                        input={<ChatbotInput isStreaming={conversation.isStreaming} onSubmit={handleSendMessage} />}
                    />
                )}
                <div className="w-full flex flex-col gap-12.5">
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
                </div>
                {conversation.errorMessage && (
                    <ChatbotError
                        message={conversation.errorMessage}
                        canRetry={canRetry}
                        onRetry={() => retryLastMessage(activeKey)}
                    />
                )}
                <div ref={scrollAnchorRef} />
                </div>
            </div>
            {!isEmptyChat && (
                <>
                    <div aria-hidden="true" className={ChatFadeStrip} />
                    <ChatbotInput isStreaming={conversation.isStreaming} onSubmit={handleSendMessage} />
                </>
            )}
        </div>
    );
}
export default Home;
//style configuration
const ChatbotContainer = clsx(
    "flex flex-col items-center",
    "w-full h-full bg-[#20232C]"
);

// 실제 스크롤되는 요소. 본문 폭 전체를 차지해 스크롤바가 오른쪽 끝에 붙는다.
// 사이드바 목록과 같은 얇은 스크롤바: 평소엔 투명, 올리면 배경에 맞춘 회색
const ChatbotScroller = clsx(
    "flex-1 min-h-0 w-full",
    "overflow-y-auto",
    "scrollbar-thin-hover",
);

// 내용 기둥. min-h-full 이라 빈 대화의 Quick Start(flex-1) 가 세로 가운데에 온다.
// 아래 여백은 페이드 띠(30px) 보다 넉넉히 두어 마지막 요소(생각 중 로고 · 답변)가 띠에 가려지지 않는다
const ChatbotLayout = clsx(
    "flex flex-col gap-4",
    "min-h-full w-[80%] max-w-full mx-auto",
    "p-6 pb-14 box-border",
);

// 대화 목록 끝에 겹쳐서 아래로 갈수록 배경색으로 녹아들고 살짝 흐려진다. 클릭·스크롤은 통과.
// 높이(h)와 끌어올림(-mt)은 같은 값으로 유지한다
const ChatFadeStrip = clsx(
    "w-full max-w-full h-7.5 shrink-0",
    "-mt-7.5 relative z-10",
    "pointer-events-none",
    "bg-[#20232C] backdrop-blur-[3px]",
    "mask-[linear-gradient(to_bottom,transparent,black)]",
);

const CenterNote = clsx(
    "flex flex-1 items-center justify-center"
);

