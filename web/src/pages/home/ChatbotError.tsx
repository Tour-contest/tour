import clsx from "clsx";

type ChatbotErrorNeedProps = {
    message: string;
    // 명세: retriable 이 true 일 때만 재시도 버튼을 보인다
    canRetry: boolean;
    onRetry: () => void;
};

// 답변 실패 안내. 재시도는 같은 질문을 다시 보내는 것이라 사용자가 다시 입력할 필요가 없다
const ChatbotError = ({ message, canRetry, onRetry } : ChatbotErrorNeedProps) => {
    return <div role="alert" className={ErrorGroup}>
        <p className={ErrorMessage}>{message}</p>
        {canRetry && (
            <button type="button" onClick={onRetry} className={RetryButton}>
                다시 시도
            </button>
        )}
    </div>
}
export default ChatbotError;
//style configuration
const ErrorGroup = clsx(
    "flex flex-wrap items-center gap-2"
);

const ErrorMessage = clsx(
    "text-[13px] text-[#ff3b30]"
);

const RetryButton = clsx(
    "rounded-[8px]",
    "border border-[#b1bdc8]",
    "px-3 py-1",
    "text-[13px]",
    "hover:bg-[#f0eee7]",
    "select-none"
);
