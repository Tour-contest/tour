//hooks
import useCurrentUser from "@/hooks/useCurrentUser";
//components
import { AnimatedLogo } from "@/components/common";
//style
import clsx from "clsx";

// 눈썹 문구(어떤 마음일 때) → 제목 → 설명. 문구는 디자인 시안 기준
const QUICK_START_PRESETS = [
    { id: 0, eyebrow: "“온천에서 푹 쉬고 싶다” 하는 분께", title: "웰니스 여행지 추천", description: "온천·휴양림 등 쉼 중심", message: "한적한 웰니스 여행지 추천해줘" },
    { id: 1, eyebrow: "“건강 검진 겸 여행 갈까?” 하는 분께", title: "의료 관광지 추천", description: "의료·헬스케어 시설 연계 관광지", message: "의료 관광지 추천해줘" },
    { id: 2, eyebrow: "“우리 강아지도 같이 가자” 하는 분께", title: "반려동물 동반 여행지 추천", description: "반려동물 입장 가능한 한적한 곳", message: "반려동물이랑 갈 수 있는 여행지 추천해줘" },
    { id: 3, eyebrow: "“날씨도 좋은데 캠핑하러 갈까?” 하는 분께", title: "캠핑 여행지 추천", description: "야영장·오토캠핑 중심", message: "한적한 캠핑 여행지 추천해줘" },
] as const;

// 어느 대화 칸(새 대화 / 기존 세션)에 보낼지는 URL 을 아는 Home 이 정하므로 전송 함수를 props 로 받는다.
// 새 대화 화면에서는 입력창이 인사말 바로 아래(화면 가운데)에 오므로 Home 이 입력창을 slot 으로 넘긴다
type ChatbotAgendaNeedProps = {
    onQuickStart: (message: string) => void;
    input: React.ReactNode;
};

// 새 채팅(빈 대화) 화면: 로고 → 인사말 → 입력창 → Quick Start 2×2
const ChatbotAgenda = ({ onQuickStart, input } : ChatbotAgendaNeedProps) => {
    // 사이드바와 같은 유저 정보를 쓴다 — 내 정보 API 를 따로 또 부르지 않는다
    const user = useCurrentUser();

    return <div className={AgendaLayout}>
        <div className={HeroGroup}>
            {/* 살아 있는 로고 (답변 생성 중 · 페이지 로딩과 같은 컴포넌트) */}
            <AnimatedLogo size={88} />
            <h2 className={Greeting}>
                안녕하세요, {user?.nickname ?? "여행자"}님 오늘은 어떤 여행지를 찾으시나요?
            </h2>
            <div className={InputSlot}>{input}</div>
        </div>

        <div className={PresetGrid}>
            {
                QUICK_START_PRESETS.map((preset) => {
                    return <button
                        type="button"
                        key={preset.id}
                        className={PresetCard}
                        onClick={() => onQuickStart(preset.message)}
                    >
                        <p className={PresetEyebrow}>{preset.eyebrow}</p>
                        <p className={PresetTitle}>{preset.title}</p>
                        <p className={PresetDescription}>{preset.description}</p>
                    </button>
                })
            }
        </div>
    </div>
}
export default ChatbotAgenda;
//style configuration
const AgendaLayout = clsx(
    "flex flex-1 flex-col gap-15 items-center justify-center",
    "py-10 box-border"
);

const HeroGroup = clsx(
    "w-full",
    "flex flex-col gap-11.25 items-center",
);

const Greeting = clsx(
    "text-center text-[24px] text-[#FFFFFF] font-medium",
    "whitespace-nowrap"
);

// Home 의 ChatbotInput(폼 자체가 720px 폭 · 아래 여백 포함)을 그대로 받는다
const InputSlot = clsx(
    "flex w-full justify-center",
    "-mb-7.5"
);

// flex 로 2×2: 카드마다 폭을 (전체 − 간격) / 2 로 고정해야 grid 처럼 두 장씩 같은 폭으로 줄이 바뀐다.
// items-stretch 라 한 줄의 두 장은 높이도 같다
const PresetGrid = clsx(
    "w-180 max-w-full",
    "flex flex-wrap items-stretch gap-[34px]"
);

// 카드: 눈썹 · 제목 · 설명. 올리면 강조색 테두리와 제목
const PresetCard = clsx(
    // 간격(34px)의 절반을 뺀 50% — 한 줄에 정확히 두 장
    "w-[calc(50%-17px)] shrink-0",
    "group flex flex-col items-center justify-center gap-3.5",
    "rounded-[12px]",
    "border border-[#3A3D47] bg-[#2A2D36]",
    "px-13.25 py-3.5 box-border",
    "text-center",
    "cursor-pointer select-none",
    "transition-[border-color,background-color] duration-150",
    "hover:border-[#6FC1FC] hover:bg-[#2C3340]",
    "focus-visible:border-[#6FC1FC] focus-visible:outline-none"
);

const PresetEyebrow = clsx(
    "text-[12px] text-[#909090] font-normal"
);

const PresetTitle = clsx(
    "text-[18px] text-[#FFFFFF] font-medium",
    "transition-colors duration-150",
    "group-hover:text-[#6FC1FC] group-focus-visible:text-[#6FC1FC]"
);

const PresetDescription = clsx(
    "text-[12px] text-[#909090] font-normal"
);
