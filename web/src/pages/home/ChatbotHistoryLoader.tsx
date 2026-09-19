import clsx from "clsx";
import { LoadingIndicator } from "@/components/common";

type ChatbotHistoryLoaderNeedProps = {
    hasMore: boolean;
    isLoading: boolean;
    onLoadOlder: () => void;
};

// 대화 목록 맨 위. 스크롤로 자동 로드되지만, 키보드 사용자와 목록이 짧아 스크롤이 안 생기는 경우를 위해 버튼도 둔다
const ChatbotHistoryLoader = ({ hasMore, isLoading, onLoadOlder } : ChatbotHistoryLoaderNeedProps) => {
    if (!hasMore && !isLoading) return null;

    return <div className={LoaderRow}>
        {isLoading ? (
            <LoadingIndicator label="이전 대화를 불러오는 중…" />
        ) : (
            <button type="button" onClick={onLoadOlder} className={LoadButton}>
                이전 대화 더 보기
            </button>
        )}
    </div>
}
export default ChatbotHistoryLoader;
//style configuration
const LoaderRow = clsx(
    "flex justify-center",
    "py-1"
);

// 대화 사이에 떠 있는 알약 버튼 — 카드색 바탕에 보조 글자, 올리면 흰 글자
const LoadButton = clsx(
    "border border-[#63717A] rounded-full",
    "bg-[#333743]",
    "px-3 py-1",
    "text-[12px] text-[#909090]",
    "cursor-pointer",
    "hover:text-[#FFFFFF] hover:border-[#FFFFFF]"
);
