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
        {/* 입력창이 기준(relative), 버튼은 그 안 오른쪽 끝에 절대 위치로 얹는다 */}
        <div className={InputWrap}>
            <input
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                maxLength={500}
                placeholder="오늘은 어떤 여행지를 찾으시나요?"
                aria-label="메시지 입력"
                className={MessageInput}
            />
            {/* 생성 중에는 비활성 — 전송 버튼이 disabled 면 Enter 암묵 제출도 막힌다 */}
            <button type="submit" disabled={isStreaming} aria-label="전송" className={SendButton}>
                <svg viewBox="0 0 24 24" aria-hidden="true" className={SendIcon}>
                    <path d="M12 19V5" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
                    <path d="M6 11l6-6 6 6" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
            </button>
        </div>
    </form>
}
export default ChatbotInput;
//style configuration
const InputForm = clsx(
    "relative z-20",
    "w-180 max-w-full",
    "pb-7.5 box-border"
);

const InputWrap = clsx(
    "relative flex items-center",
    "w-full"
);

const MessageInput = clsx(
    "min-w-0 h-[60px]",
    "flex-1",
    "border border-[#63717A] rounded-full",
    "pl-6 pr-[68px] box-border",
    "bg-[#454C52]",
    "text-[#FFFFFF] text-[17px] font-normal",
    "outline-none",
    "transition-[border-color,box-shadow] duration-150",
    "focus:border-[#A3F1F9]",
    "focus:shadow-[0_0_0_1.4px_#A3F1F9,0_0_12px_rgba(163,241,249,0.35)]",
);

const SendButton = clsx(
    "absolute right-[6px] top-1/2 -translate-y-1/2",
    "flex items-center justify-center",
    "size-12 rounded-full",
    "bg-linear-to-b from-[#A3F1F9] to-[#309AE6]",
    "text-white",
    "shadow-[0_2px_8px_rgba(48,154,230,0.45)]",
    "cursor-pointer select-none",
    "transition-[transform,opacity,filter] duration-150",
    "hover:brightness-110 active:scale-95",
    "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:brightness-100 disabled:active:scale-100"
);

const SendIcon = clsx(
    "size-6"
);
