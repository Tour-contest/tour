import clsx from "clsx";
import { isAreaOverviewPayload, resolveFollowUps } from "./followUp";
import AlternativesCard from "./cards/AlternativesCard";
import CrowdAttractionCard from "./cards/CrowdAttractionCard";
import { formatDateLabel } from "./cards/crowdVisual";

const cardStyle = clsx(
    "flex",
    "flex-col",
    "gap-[8px]",
    "rounded-[12px]",
    "border-[1px]",
    "border-[#e5e4e7]",
    "p-[16px]",
    "text-[13px]",
);

const cardTitleStyle = clsx("text-[14px]", "font-bold");
const sourceStyle = clsx("text-[12px]", "text-[#6b6375]");

const LevelTextStyle = {
    혼잡: "text-[#ff3b30]",
    보통: "text-[#c8860a]",
    한적: "text-[#1a8c4a]",
} as const;

type ChatCardViewProps = {
    card: ChatCard;
};

// 카드 종류별 렌더러로 분기한다. SB-03 두 카드는 cards/ 로 분리했고, 나머지는 아직 수신 확인용 최소 렌더
const ChatCardView = ({ card }: ChatCardViewProps) => {
    // 데이터가 없는 카드는 그리지 않는다 — 대신 말풍선 아래 후속 질문 버튼(ChatFollowUps)으로 대체된다
    if (resolveFollowUps(card) !== null) return null;

    switch (card.type) {
        case "crowd": {
            if (isAreaOverviewPayload(card.payload)) {
                const { signgu_nm, date, summary, coverage, source } = card.payload;

                return (
                    <div className={cardStyle}>
                        <p className={cardTitleStyle}>{signgu_nm} {formatDateLabel(date)} 현황</p>
                        <p>
                            <span className={LevelTextStyle.혼잡}>혼잡 {summary?.crowded ?? 0}곳</span>
                            {" · "}
                            <span className={LevelTextStyle.보통}>보통 {summary?.normal ?? 0}곳</span>
                            {" · "}
                            <span className={LevelTextStyle.한적}>한적 {summary?.quiet ?? 0}곳</span>
                        </p>
                        {coverage && (
                            <p className={sourceStyle}>
                                관광정보 {coverage.tourapi_total}곳 중 집중률 보유 {coverage.with_crowd_data}곳
                            </p>
                        )}
                        {source && <p className={sourceStyle}>{source}</p>}
                    </div>
                );
            }

            return <CrowdAttractionCard payload={card.payload} />;
        }

        case "attraction_list":
            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>{card.payload.signgu_nm ?? "관광지"}</p>
                    {card.payload.items.map((item) => (
                        <p key={item.content_id}>
                            {item.title}
                            {item.addr1 && <span className={sourceStyle}> · {item.addr1}</span>}
                        </p>
                    ))}
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );

        case "alternatives":
            return <AlternativesCard payload={card.payload} />;

        case "detail":
        case "attraction":
            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>{card.payload.title}</p>
                    {card.payload.addr1 && <p>{card.payload.addr1}</p>}
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );

        case "area_overview": {
            const { signgu_nm, date, summary, source } = card.payload;

            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>{signgu_nm} {formatDateLabel(date)} 현황</p>
                    <p>
                        혼잡 {summary?.crowded ?? 0}곳 · 보통 {summary?.normal ?? 0}곳 · 한적 {summary?.quiet ?? 0}곳
                    </p>
                    {source && <p className={sourceStyle}>{source}</p>}
                </div>
            );
        }

        case "visitors":
            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>{card.payload.signgu_nm} 방문자 추세</p>
                    {card.payload.items.map((item) => (
                        <p key={item.date}>
                            {item.date} · {item.total.toLocaleString()}명
                        </p>
                    ))}
                    <p className={sourceStyle}>{card.payload.data_through} 까지의 자료</p>
                </div>
            );

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
