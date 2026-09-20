import clsx from "clsx";
import { isAreaOverviewPayload, resolveFollowUps } from "./followUp";
import AlternativesCard from "./cards/AlternativesCard";
import AreaOverviewCard from "./cards/AreaOverviewCard";
import AreaVisitorsCard from "./cards/AreaVisitorsCard";
import AttractionCard from "./cards/AttractionCard";
import CrowdAttractionCard from "./cards/CrowdAttractionCard";
import BestSuggestionCard from "./cards/BestSuggestionCard";

// 관광지 목록 · 단일 관광지 카드의 껍데기 (다른 대화 카드와 같은 톤). 항목 행은 cards/AttractionCard
const cardStyle = clsx(
    "flex flex-col gap-3",
    "rounded-[12px]",
    "bg-[#333743]",
    "p-[22px_32px] box-border",
    "text-[13px]",
);

const cardTitleStyle = clsx("text-[20px]", "text-[#FFFFFF]", "font-medium");
const sourceStyle = clsx("text-[12px]", "text-[#909090]");
const itemListStyle = clsx("flex", "flex-col");

type ChatCardViewProps = {
    card: ChatCard;
};

// 카드 종류별 렌더러로 분기한다. SB-03 두 카드는 cards/ 로 분리했고, 나머지는 아직 수신 확인용 최소 렌더
const ChatCardView = ({ card }: ChatCardViewProps) => {
    // 데이터가 없는 카드는 그리지 않는다 — 대신 말풍선 아래 후속 질문 버튼(ChatFollowUps)으로 대체된다
    if (resolveFollowUps(card) !== null) return null;

    switch (card.type) {
        // 지역 전체 형태(summary 보유)는 SB-05 도넛 카드 + 그 지역에서 가장 한적한 곳(가장 추천), 관광지 지정 형태는 SB-03 막대 카드.
        // 이어서 alternatives 카드가 오면 "다른 대안" 흐름이 된다
        case "crowd":
            return isAreaOverviewPayload(card.payload)
                ? <><AreaOverviewCard payload={card.payload} /><BestSuggestionCard payload={card.payload} /></>
                : <CrowdAttractionCard payload={card.payload} />;

        case "attraction_list":
            return (
                <div className={cardStyle}>
                    <h4 className={cardTitleStyle}>{card.payload.signgu_nm ?? "관광지"}</h4>
                    <div className={itemListStyle}>
                        {card.payload.items.map((item) => (
                            <AttractionCard
                                key={item.content_id}
                                contentId={item.content_id}
                                title={item.title}
                                image={item.image}
                                note={item.addr1 ?? item.period ?? item.note}
                                region={card.payload.signgu_nm}
                            />
                        ))}
                    </div>
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );

        case "alternatives":
            return <AlternativesCard payload={card.payload} />;

        case "detail":
        case "attraction":
            return (
                <div className={cardStyle}>
                    <AttractionCard
                        contentId={card.payload.content_id}
                        title={card.payload.title}
                        image={card.payload.image}
                        note={card.payload.addr1}
                        region={card.payload.signgu_nm}
                    />
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );

        case "area_overview":
            return <><AreaOverviewCard payload={card.payload} /><BestSuggestionCard payload={card.payload} /></>;

        case "visitors":
            return <AreaVisitorsCard payload={card.payload} />;

        // 카드가 아니라 1행 안내이며, flat 이면 표시하지 않는다
        case "interest":
            return (
                <>
                    {card.payload.items
                        .filter((item) => item.trend !== "flat")
                        .map((item) => (
                            <p key={item.name} className={sourceStyle}>
                                {item.display_name} 검색 관심도 {item.trend === "rising" ? "상승" : "하락"} {item.change_pct}%
                            </p>
                        ))}
                </>
            );

        default:
            return null;
    }
};
export default ChatCardView;
