import { useState } from "react";
import clsx from "clsx";

type ChatbotInputNeedProps = {
    isStreaming: boolean;
    onSubmit: (message: string) => void;
};

// 타이핑 중인 값은 입력창만 알면 되므로 여기서 소유한다
const ChatbotInput = ({ isStreaming, onSubmit } : ChatbotInputNeedProps) => {
    const [inputValue, setInputValue] = useState<string>("");

    const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();

        onSubmit(inputValue);
        setInputValue("");
    };

    return <form onSubmit={handleSubmit} className={InputForm}>
        <input
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            maxLength={500}
            placeholder="오늘은 어떤 여행지를 찾으시나요?"
            aria-label="메시지 입력"
            className={MessageInput}
        />
        {/* 생성 중에는 비활성 — 전송 버튼이 disabled 면 Enter 암묵 제출도 막힌다 */}
        <button type="submit" disabled={isStreaming} className={SendButton}>
            전송
        </button>
    </form>
}
export default ChatbotInput;
//style configuration
const InputForm = clsx(
    "flex gap-2",
    "w-180 max-w-full",
    "p-6 pt-0 box-border"
);

const MessageInput = clsx(
    "flex-1 min-w-0",
    "border border-[#b1bdc8] rounded-[16px]",
    "px-4 py-3"
);

const SendButton = clsx(
    "rounded-[16px]",
    "bg-[#222] text-white",
    "px-5",
    "disabled:opacity-50"
);
