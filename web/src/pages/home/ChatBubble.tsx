import type { ChatViewMessage } from "@/store/chat";
import clsx from "clsx";

type ChatBubbleNeedProps = {
    role: ChatViewMessage["role"];
    children: React.ReactNode;
};

const ChatBubble = ({ role, children } : ChatBubbleNeedProps) => {
    return <p className={clsx(BubbleRole[role])}>{children}</p>
}
export default ChatBubble;
//style configuration
const BubbleRole = {
    user: clsx(
        "self-end", 
        "bg-[#1A1C22] max-w-160", 
        "text-[#FFFFFF] text-[14px] font-normal",
        "rounded-[16px]",
        "px-4 py-3 box-border"
    ),
    assistant: clsx(
        "self-start",
        "max-w-160", 
        "text-[#FFFFFF] text-[14px] font-normal",
    ),
} as const;
