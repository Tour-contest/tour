import { ChatCardView } from "@/components/chat";
import { LoadingIndicator } from "@/components/common";
import clsx from "clsx";
import ChatBubble from "./ChatBubble";

type ChatbotStreamingNeedProps = {
    streamingCards: ChatCard[];
    statusLabel: string | null;
    streamingText: string;
};

// 카드가 문장보다 먼저 도착하므로 카드 → 진행 문구 → 누적 텍스트 순으로 쌓는다
const ChatbotStreaming = ({ streamingCards, statusLabel, streamingText } : ChatbotStreamingNeedProps) => {
    return <div className={StreamingNote}>
        {
            streamingCards.map((card, index) => {
                return <ChatCardView key={`streaming-${index}`} card={card} />
            })
        }
        {statusLabel && <LoadingIndicator label={`${statusLabel}…`} />}
        {streamingText && <ChatBubble role="assistant">{streamingText}</ChatBubble>}
    </div>
}
export default ChatbotStreaming;
//style configuration
const StreamingNote = clsx(
    "flex flex-col gap-2"
);
