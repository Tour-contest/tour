import clsx from "clsx";
import { isAreaOverviewPayload, resolveFollowUps } from "./followUp";
import AlternativesCard from "./cards/AlternativesCard";
import AreaOverviewCard from "./cards/AreaOverviewCard";
import AreaVisitorsCard from "./cards/AreaVisitorsCard";
import AttractionCard from "./cards/AttractionCard";
import CrowdAttractionCard from "./cards/CrowdAttractionCard";
import BestSuggestionCard from "./cards/BestSuggestionCard";

type ChatCardViewProps = {
    card: ChatCard;
};

const ChatCardView = ({ card }: ChatCardViewProps) => {
    // 데이터가 없는 카드는 그리지 않는다 — 대신 말풍선 아래 후속 질문 버튼(ChatFollowUps)으로 대체된다
    if (resolveFollowUps(card) !== null) return null;

    switch (card.type) {
        case "crowd":
            return isAreaOverviewPayload(card.payload)
                ? <><AreaOverviewCard payload={card.payload} /><BestSuggestionCard payload={card.payload} /></>
                : <CrowdAttractionCard payload={card.payload} />;

        case "attraction_list":
            return (
                <div className={CardStyle}>
                    <h4 className={CardTitleStyle}>{card.payload.signgu_nm ?? "관광지"}</h4>
                    <div className={ItemListStyle}>
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
                    {card.payload.source && <p className={SourceStyle}>{card.payload.source}</p>}
                </div>
            );

        case "alternatives":
            return <AlternativesCard payload={card.payload} />;

        case "detail":
        case "attraction":
            return (
                <div className={CardStyle}>
                    <AttractionCard
                        contentId={card.payload.content_id}
                        title={card.payload.title}
                        image={card.payload.image}
                        note={card.payload.addr1}
                        region={card.payload.signgu_nm}
                    />
                    {card.payload.source && <p className={SourceStyle}>{card.payload.source}</p>}
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
                            <p key={item.name} className={SourceStyle}>
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
//style configuration
const CardStyle = clsx(
    "w-180 bg-[#333743]",
    "flex flex-col gap-3",
    "rounded-[12px]",
    "p-[22px_32px] box-border",
    "text-[13px]",
);

const CardTitleStyle = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);
const SourceStyle = clsx(
    "text-[12px] text-[#909090] font-normal"
);
const ItemListStyle = clsx(
    "flex flex-col"
);
