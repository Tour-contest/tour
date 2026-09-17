import clsx from "clsx";
import { useSystemStore } from "@/store/system";

// 심각한 순서. 여러 개가 동시에 꺼져 있어도 사용자에게는 가장 큰 영향 하나만 말한다
// (llm_enabled 는 명세상 응답 형태가 같아 화면에 알리지 않는다)
const resolveServiceNotice = (ready: ReadyData): string | null => {
    if (!ready.service_key_set) return "지금은 관광 정보를 불러올 수 없어요. 혼잡도·관광지 답변이 제한돼요.";
    if (ready.areas_loaded === 0) return "지금은 지역별 조회를 쓸 수 없어요. 지역 이름으로 묻는 질문이 제한돼요.";
    if (!ready.embedding_ready) return "지금은 비슷한 관광지 추천이 제한돼요.";
    return null;
};

// 첫 화면 기능 활성 안내 (명세: readyz). 질문을 보내고 나서야 "자료 없음"을 받는 대신,
// 서버 설정 문제는 미리 알려 헛질문과 오해를 줄인다. 문제가 없으면 아무것도 그리지 않는다
const ChatbotServiceNotice = () => {
    const ready = useSystemStore((state) => state.ready);
    const notice = ready ? resolveServiceNotice(ready) : null;

    if (!notice) return null;

    return <p role="status" className={Notice}>{notice}</p>
}
export default ChatbotServiceNotice;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지금은 구조만
// 대화 영역과 같은 폭으로 맞춘다
const Notice = clsx(
    "w-180 max-w-full",
    "mt-4",
    "rounded-[8px]",
    "border border-[#f3d9a4]",
    "bg-[#fff8e6]",
    "px-4 py-2",
    "text-[13px] text-[#7a5a00]"
);
