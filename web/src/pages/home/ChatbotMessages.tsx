import { ChatCardView, ChatFollowUps } from "@/components/chat";
import type { ChatViewMessage } from "@/store/chat";
import clsx from "clsx";
import ChatBubble from "./ChatBubble";
import ChatbotRegionRetry from "./ChatbotRegionRetry";

type ChatbotMessagesNeedProps = {
    chatMessage: ChatViewMessage[];
    onSendMessage: (message: string) => void;
    isSendDisabled: boolean;
};

const ChatbotMessages = ({ chatMessage, onSendMessage, isSendDisabled } : ChatbotMessagesNeedProps) => {
    return chatMessage.map((message: ChatViewMessage, index: number) => {
        // 후속 질문 · 다시 묻기는 지금 이어갈 대화에만 의미가 있어 마지막 답변에만 붙인다
        const isLastAssistant = message.role === "assistant" && index === chatMessage.length - 1;
        const previousMessage = chatMessage[index - 1];
        const originalQuestion = previousMessage?.role === "user" ? previousMessage.content : null;

        return <div key={message.key} className={MessageNote}>
            {
                message.cards.map((card, cardIndex) => {
                    return <ChatCardView key={`${message.key}-${cardIndex}`} card={card} />
                })
            }
            <ChatBubble role={message.role}>{message.content}</ChatBubble>
            {message.sourceNote && <p className={SourceNote}>{message.sourceNote}</p>}
            {isLastAssistant && (
                <>
                    <ChatFollowUps cards={message.cards} onFollowUp={onSendMessage} isDisabled={isSendDisabled} />
                    {originalQuestion && (
                        <ChatbotRegionRetry
                            originalMessage={originalQuestion}
                            isDisabled={isSendDisabled}
                            onResend={onSendMessage}
                        />
                    )}
                </>
            )}
        </div>
    })
}
export default ChatbotMessages;
//style configuration
// key 가 같은 기존 메시지는 DOM 이 유지되므로, 애니메이션은 새로 삽입된 것(이전 묶음·새 답변)에만 돈다
const MessageNote = clsx(
    "flex flex-col gap-2",
    "animate-fade-in motion-reduce:animate-none"
);

const SourceNote = clsx(
    "text-[12px] text-[#6b6375]"
);
