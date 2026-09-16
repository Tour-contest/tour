import { useEffect, useRef, useState } from "react";
import { useParams } from "react-router";
import clsx from "clsx";
import { ChatCardView } from "@/components/chat";
import { useChatStream } from "@/hooks/api";
import ChatbotAgenda from "./ChatbotAgenda";

const ATTRIBUTION = "출처: ⓒ한국관광공사";

const bubbleBaseStyle = clsx("max-w-[640px]", "rounded-[16px]", "px-[16px]", "py-[12px]", "text-[14px]");

const BubbleStyle = {
    user: clsx(bubbleBaseStyle, "self-end", "bg-[#222]", "text-white"),
    assistant: clsx(bubbleBaseStyle, "self-start", "bg-[#f4f3ec]"),
} as const;

function Home() {
    // 세션은 URL 이 소유한다 — 사이드바에서 고른 대화(/c/:sessionId), 없으면 새 대화(/)
    const { sessionId } = useParams<{ sessionId: string }>();
    const { chat, sendMessage, loadSession, resetChat } = useChatStream();
  
    const [inputValue, setInputValue] = useState<string>("");
    const scrollAnchorRef = useRef<HTMLDivElement | null>(null);

    useEffect(() => {
        if (sessionId) loadSession(sessionId);
        else resetChat();
    }, [sessionId]);

    useEffect(() => {
        scrollAnchorRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [chat.messages, chat.streamingText]);

    const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();

        sendMessage(inputValue);
        setInputValue("");
    };

    const isEmptyChat = chat.messages.length === 0 && !chat.isStreaming;

    return (
        <div className={ChatbotContainer}>
            <div className={ChatbotLayout}>
                {isEmptyChat && <ChatbotAgenda />}
                {chat.messages.map((message) => (
                    <div key={message.key} className={clsx("flex", "flex-col", "gap-[8px]")}>
                        {message.cards.map((card, index) => (
                            <ChatCardView key={`${message.key}-${index}`} card={card} />
                        ))}
                        <p className={BubbleStyle[message.role]}>{message.content}</p>
                        {message.sourceNote && (
                            <p className={clsx("text-[12px]", "text-[#6b6375]")}>{message.sourceNote}</p>
                        )}
                    </div>
                ))}

                {chat.isStreaming && (
                    <div className={clsx("flex", "flex-col", "gap-[8px]")}>
                        {chat.streamingCards.map((card, index) => (
                            <ChatCardView key={`streaming-${index}`} card={card} />
                        ))}
                        {chat.statusLabel && (
                            <p className={clsx("text-[13px]", "text-[#6b6375]")}>{chat.statusLabel}…</p>
                        )}
                        {chat.streamingText && <p className={BubbleStyle.assistant}>{chat.streamingText}</p>}
                    </div>
                )}

                {chat.errorMessage && (
                    <p className={clsx("text-[13px]", "text-[#ff3b30]")}>{chat.errorMessage}</p>
                )}

                <div ref={scrollAnchorRef} />
            </div>

            <form
                onSubmit={handleSubmit}
                className={clsx("flex", "w-[720px]", "max-w-full", "gap-[8px]", "p-[24px]", "pt-0")}
            >
                <input
                    value={inputValue}
                    onChange={(e) => setInputValue(e.target.value)}
                    maxLength={500}
                    placeholder="오늘은 어떤 여행지를 찾으시나요?"
                    aria-label="메시지 입력"
                    className={clsx("flex-1", "min-w-0", "rounded-[16px]", "border-[1px]", "border-[#b1bdc8]", "px-[16px]", "py-[12px]")}
                />
                <button
                    type="submit"
                    disabled={chat.isStreaming}
                    className={clsx("rounded-[16px]", "bg-[#222]", "px-[20px]", "text-white", "disabled:opacity-50")}
                >
                    전송
                </button>
            </form>

            <p className={clsx("pb-[16px]", "text-[12px]", "text-[#6b6375]")}>{ATTRIBUTION}</p>
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

const ChatboxGuideLayout = clsx(
    "flex", "flex-1", "flex-col", "justify-center", "gap-6"
);

const ChatboxGuideTitleGroup = clsx(
    "flex flex-col gap-2"
);

const ChatboxGuideTitle = clsx(
    "text-[24px] font-bold"
);

const ChatboxGuideAddendumText = clsx(
    "text-[14px] text-[#6b6375]"
);