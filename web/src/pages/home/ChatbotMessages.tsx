import type { ChatViewMessage } from "@/hooks/api/useChatStream";
import clsx from "clsx";

type ChatbotMessagesNeedProps = {
    chatMessage: ChatViewMessage[];
};

const ChatbotMessages = ({ chatMessage } : ChatbotMessagesNeedProps) => {
    return chatMessage.map((message: ChatViewMessage) => {
        return <div key={message.key} className={MessageNote}>

        </div>
    })
}
export default ChatbotMessages;
//style configuration
const MessageNote = clsx(
    "flex flex-col gap-2"
);