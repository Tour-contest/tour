import clsx from "clsx";

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

// 지역 전체 혼잡도는 summary 가 있고, 관광지 지정 혼잡도는 items 에 series 가 있다
const isAreaOverviewPayload = (
    payload: ChatCrowdAttractionPayload | AreaOverviewData,
): payload is AreaOverviewData => "summary" in payload && payload.summary !== undefined;

type ChatCardViewProps = {
    card: ChatCard;
};

// TODO: SB-03 카드 디자인으로 교체 — 현재는 수신 데이터 확인용 최소 렌더
const ChatCardView = ({ card }: ChatCardViewProps) => {
    switch (card.type) {
        case "crowd": {
            if (isAreaOverviewPayload(card.payload)) {
                const { signgu_nm, summary, coverage, source } = card.payload;

                return (
                    <div className={cardStyle}>
                        <p className={cardTitleStyle}>{signgu_nm} 오늘 현황</p>
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

            const target = card.payload.items.find((item) => item.series.length > 0);

            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>
                        {target?.name ?? "혼잡도"} {card.payload.signgu_nm && `· ${card.payload.signgu_nm}`}
                    </p>
                    {target?.series.map((day) => (
                        <p key={day.date}>
                            {day.weekday} <span className={LevelTextStyle[day.level]}>{day.level}</span> {day.rate}
                        </p>
                    ))}
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );
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
            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>
                        {card.payload.base.name} 대신 여기는 어때요?
                    </p>
                    {card.payload.items.map((item) => (
                        <p key={item.content_id}>
                            {item.name} <span className={LevelTextStyle[item.level]}>{item.level}</span> {item.rate}
                        </p>
                    ))}
                    {card.payload.source && <p className={sourceStyle}>{card.payload.source}</p>}
                </div>
            );

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
            const { signgu_nm, summary, source } = card.payload;

            return (
                <div className={cardStyle}>
                    <p className={cardTitleStyle}>{signgu_nm} 오늘 현황</p>
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
