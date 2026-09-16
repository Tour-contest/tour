import type { ChatViewMessage } from "@/store/chat";
import clsx from "clsx";

type ChatBubbleNeedProps = {
    role: ChatViewMessage["role"];
    children: React.ReactNode;
};

const ChatBubble = ({ role, children } : ChatBubbleNeedProps) => {
    return <p className={clsx(BubbleBase, BubbleRole[role])}>{children}</p>
}
export default ChatBubble;
//style configuration
const BubbleBase = clsx(
    "max-w-[640px] rounded-[16px]",
    "px-4 py-3",
    "text-[14px]"
);

const BubbleRole = {
    user: clsx("self-end", "bg-[#222] text-white"),
    assistant: clsx("self-start", "bg-[#f4f3ec]"),
} as const;
