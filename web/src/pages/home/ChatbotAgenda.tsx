import { useUser } from "@/hooks/api";
import clsx from "clsx";
import { useEffect } from "react";

const QUICK_START_PRESETS = [
    { id: 0, title: "웰니스 여행지 추천", description: "온천·휴양림 등 쉼", message: "한적한 웰니스 여행지 추천해줘" },
    { id: 1, title: "의료 관광지 추천", description: "의료·헬스케어 연계", message: "의료 관광지 추천해줘" },
    { id: 2, title: "반려동물 동반", description: "반려동물 입장 가능", message: "반려동물이랑 갈 수 있는 여행지 추천해줘" },
    { id: 3, title: "캠핑 여행지 추천", description: "야영장·오토캠핑", message: "한적한 캠핑 여행지 추천해줘" },
] as const;

// 어느 대화 칸(새 대화 / 기존 세션)에 보낼지는 URL 을 아는 Home 이 정하므로 전송 함수를 props 로 받는다
type ChatbotAgendaNeedProps = {
    onQuickStart: (message: string) => void;
};

const ChatbotAgenda = ({ onQuickStart } : ChatbotAgendaNeedProps) => {
    const { fetchMyInfo, myInfo } = useUser();

    useEffect(() => {
        fetchMyInfo();
    }, [])

    const handleQuickStartClick = (message: string) => {
        onQuickStart(message);
    };

    return <div className={ChatbotTouristAgendaLayout}>
        <div className={ChatbotAgendaTitleGroup}>
            <h2 className={ChatbotAgendaTitle}>안녕하세요, {myInfo?.nickname} 님</h2>
            <p className={ChatbotAgendaQuestion}>어떤 여행지를 찾으시나요?</p>
        </div>
        <div className={ChatbotAgendaThemeGroup}>
            {
                QUICK_START_PRESETS.map((preset) => {
                    return <button
                        type="button" 
                        key={preset.id} 
                        className={TouristAgenda}
                        onClick={() => handleQuickStartClick(preset.message)}
                    >
                        <p className={TouristAgendaTitle}>{preset.title}</p>
                        <p className={TouristAgendaDescription}>{preset.description}</p>
                    </button>
                })
            }
        </div>
    </div>
}
export default ChatbotAgenda;
//style configuration
const ChatbotTouristAgendaLayout = clsx(
    "flex flex-1 flex-col justify-center gap-6"
);

const ChatbotAgendaTitleGroup = clsx(
    "flex flex-col gap-2"
);

const ChatbotAgendaTitle = clsx(
    "text-[24px] font-bold"
);

const ChatbotAgendaQuestion = clsx(
    "text-[14px] text-[#6b6375]"
);

const ChatbotAgendaThemeGroup = clsx(
    "grid grid-cols-2 gap-3"
);

const TouristAgenda = clsx(
    "flex flex-col gap-1",
    "border border-[#e5e4e7] rounded-[12px]",
    "p-4 box-border",
    "text-left",
    "cursor-pointer"
);

const TouristAgendaTitle = clsx(
    "text-[14px] font-bold"
);

const TouristAgendaDescription = clsx(
    "text-[12px] text-[#6b6375] font-regular"
);