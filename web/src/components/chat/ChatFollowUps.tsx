import clsx from "clsx";
import { resolveFollowUps, type FollowUp } from "./followUp";

type ChatFollowUpsNeedProps = {
    cards: ChatCard[];
    onFollowUp: (message: string) => void;
    isDisabled: boolean;
};

// 데이터가 없어 카드를 그리지 못한 자리를 다음 질문으로 이어준다 (SB-04 "대화가 막다른 길이 되지 않음")
const ChatFollowUps = ({ cards, onFollowUp, isDisabled } : ChatFollowUpsNeedProps) => {
    // 카드 여러 장이 같은 지역을 가리키면 같은 버튼이 겹치므로 보낼 문장 기준으로 한 번만 남긴다
    const followUps = cards
        .flatMap((card) => resolveFollowUps(card) ?? [])
        .filter((followUp, index, list) => list.findIndex((item) => item.message === followUp.message) === index);

    if (followUps.length === 0) return null;

    return <div className={FollowUpGroup}>
        {
            followUps.map((followUp: FollowUp) => {
                return <button
                    key={followUp.message}
                    type="button"
                    disabled={isDisabled}
                    onClick={() => onFollowUp(followUp.message)}
                    className={FollowUpButton}
                >
                    {followUp.label}
                </button>
            })
        }
    </div>
}
export default ChatFollowUps;
//style configuration
const FollowUpGroup = clsx(
    "flex flex-wrap gap-2",
    "self-start"
);

// 어두운 칩. 올리면 강조색 테두리와 흰 글자로 "누를 수 있는 것" 임을 드러낸다
const FollowUpButton = clsx(
    "border border-[#63717A] rounded-[12px]",
    "bg-[#333743]",
    "px-3 py-2",
    "text-[13px] text-[#D8D8D8]",
    "cursor-pointer",
    "transition-colors duration-150",
    "hover:border-[#6FC1FC] hover:text-[#FFFFFF]",
    "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:border-[#63717A] disabled:hover:text-[#D8D8D8]"
);
