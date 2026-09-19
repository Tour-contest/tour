//style
import clsx from "clsx";
//components
import { AnimatedLogo } from "@/components/common";

type ChatbotThinkingNeedProps = {
    // 서버 status 이벤트의 진행 문구 (예: "혼잡도 확인 중")
    label: string;
};

// 답변을 만드는 동안 말풍선 자리에 보이는 "생각 중" 표시 — 살아 있는 로고 + 진행 문구
const ChatbotThinking = ({ label } : ChatbotThinkingNeedProps) => {
    return <div role="status" className={Layout}>
        <AnimatedLogo size={36} hasGlow={false} />
        <p className={Label}>{label}…</p>
    </div>
}
export default ChatbotThinking;
//style configuration
const Layout = clsx(
    "flex items-center gap-3",
    "self-start",
    "px-1 py-1"
);

const Label = clsx(
    "text-[14px] text-[#909090] font-normal"
);
