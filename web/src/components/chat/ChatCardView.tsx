import { Link } from "react-router";
import clsx from "clsx";
import { isAreaOverviewPayload, resolveFollowUps } from "./followUp";
import AlternativesCard from "./cards/AlternativesCard";
import AreaOverviewCard from "./cards/AreaOverviewCard";
import CrowdAttractionCard from "./cards/CrowdAttractionCard";

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

// 관광지 항목은 상세(/attractions/:id)로 이어진다. 응답에 딸려온 대표 이미지가 있으면 썸네일로 같이 보여준다
const attractionRowStyle = clsx("flex", "items-center", "gap-[10px]");
const thumbnailStyle = clsx("size-[40px]", "shrink-0", "rounded-[8px]", "object-cover", "bg-[#f4f3ec]");
const attractionLinkStyle = clsx("min-w-0", "truncate", "hover:underline");

type AttractionLinkRowProps = {
    contentId: string;
    title: string | null | undefined;
    image?: string | null;
    note?: string | null;
};

const AttractionLinkRow = ({ contentId, title, image, note }: AttractionLinkRowProps) => (
    <div className={attractionRowStyle}>
        {image && <img src={image} alt="" loading="lazy" className={thumbnailStyle} />}
        <p className={clsx("min-w-0", "truncate")}>
            <Link to={`/attractions/${contentId}`} className={attractionLinkStyle}>{title || "이름 없는 관광지"}</Link>
            {note && <span className={sourceStyle}> · {note}</span>}
        </p>
    </div>
);

type ChatCardViewProps = {
    card: ChatCard;
};

// 카드 종류별 렌더러로 분기한다. SB-03 두 카드는 cards/ 로 분리했고, 나머지는 아직 수신 확인용 최소 렌더
const ChatCardView = ({ card }: ChatCardViewProps) => {
    // 데이터가 없는 카드는 그리지 않는다 — 대신 말풍선 아래 후속 질문 버튼(ChatFollowUps)으로 대체된다
    if (resolveFollowUps(card) !== null) return null;

    switch (card.type) {
        // 지역 전체 형태(summary 보유)는 SB-05 도넛 카드, 관광지 지정 형태는 SB-03 막대 카드
        case "crowd":
            return isAreaOverviewPayload(card.payload)
                ? <AreaOverviewCard payload={card.payload} />
                : <CrowdAttractionCard payload={card.payload} />;

        case "attraction_list":
            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>{card.payload.signgu_nm ?? "관광지"}</p>
                    {card.payload.items.map((item) => (
                        <AttractionLinkRow
                            key={item.content_id}
                            contentId={item.content_id}
                            title={item.title}
                            image={item.image}
                            note={item.addr1 ?? item.period ?? item.note}
                        />
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
                    <AttractionLinkRow
                        contentId={card.payload.content_id}
                        title={card.payload.title}
                        image={card.payload.image}
                        note={card.payload.addr1}
                    />
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );

        case "area_overview":
            return <AreaOverviewCard payload={card.payload} />;

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
