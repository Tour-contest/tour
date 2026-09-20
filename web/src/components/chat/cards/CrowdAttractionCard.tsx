import { useState } from "react";
import { Link } from "react-router";
import clsx from "clsx";
import LevelChip from "./LevelChip";
import {
    LevelDotBase,
    LevelFill,
    buildKakaoMapSearchUrl,
    formatDateLabel,
    formatRate,
    formatShortDate,
    isToday,
} from "./utils/crowdVisual";

type CrowdAttractionCardNeedProps = {
    payload: ChatCrowdAttractionPayload;
    // 상세 화면이 자기 혼잡도를 그릴 때는 제목이 자기 자신으로 가는 링크가 되지 않게 끈다
    isTitleLink?: boolean;
};

// 카드 그래프는 한 주(SB-03)만 그리고, 나머지 날짜는 표 보기로 연다
const CHART_DAYS = 7;
// 막대 위에 수치 라벨이 들어갈 여백을 남기고 그린다 (라벨이 막대 영역 밖으로 넘치지 않게)
const BAR_MAX_HEIGHT_PERCENT = 80;

// SB-03 STEP 2 — 관광지 지정 혼잡도
const CrowdAttractionCard = ({ payload, isTitleLink = true } : CrowdAttractionCardNeedProps) => {
    const [isForecastOpen, setIsForecastOpen] = useState<boolean>(false);

    // 명세: 그래프는 items 중 series 가 있는 첫 항목으로 구성한다
    const target = payload.items.find((item) => item.series.length > 0);
    if (!target) return null;

    const { series } = target;
    const region = payload.signgu_nm;
    const focusPoint = series.find((point) => isToday(point.date)) ?? series[0];
    const chartPoints = series.slice(0, CHART_DAYS);

    const rates = chartPoints.map((point) => point.rate);
    const maxRate = Math.max(...rates);
    const minRate = Math.min(...rates);
    // 집중률은 0~100 지수라 고정 눈금으로 그려야 다른 카드의 막대와 높이를 비교할 수 있다
    const scaleMax = Math.max(100, maxRate);

    const hasMoreForecast = !!target.available_days && target.available_days > series.length;
    const mapKeyword = region ? `${region} ${target.name}` : target.name;

    return <div className={CardShell}>
        <div className={CardHeader}>
            <div className={TitleGroup}>
                {isTitleLink && target.content_id ? (
                    <Link to={`/attractions/${target.content_id}`} className={clsx(CardTitle, "hover:underline")}>{target.name}</Link>
                ) : (
                    <p className={CardTitle}>{target.name}</p>
                )}
                {region && <p className={Muted}>{region}</p>}
            </div>
            <LevelChip level={focusPoint.level} rate={focusPoint.rate} prefix={formatDateLabel(focusPoint.date)} />
        </div>

        {/* 명세: match_method 가 exact 가 아니면 매칭된 이름을 안내한다 */}
        {target.match_method && target.match_method !== "exact" && target.matched_title && (
            <p className={Muted}>'{target.matched_title}' 자료로 확인했어요</p>
        )}

        <div>
            <div className={ChartPlot}>
                {
                    chartPoints.map((point, index) => {
                        const pointLabel = `${formatDateLabel(point.date)}(${point.weekday}) ${point.level} ${formatRate(point.rate)}`;
                        // 모든 막대에 숫자를 달지 않고 최고·최저만 표시한다. 나머지는 툴팁과 표 보기로 읽는다
                        const isExtreme = maxRate !== minRate && (point.rate === maxRate || point.rate === minRate);
                        // 양 끝 막대의 툴팁이 카드 밖으로 넘쳐 가로 스크롤이 생기지 않게 안쪽으로 붙인다
                        const tooltipAlign = index === 0 ? TooltipAlign.start : index === chartPoints.length - 1 ? TooltipAlign.end : TooltipAlign.center;

                        return <div key={point.date} role="img" tabIndex={0} aria-label={pointLabel} className={BarSlot}>
                            <span aria-hidden="true" className={clsx(BarTooltip, tooltipAlign)}>{pointLabel}</span>
                            {isExtreme && <span aria-hidden="true" className={BarValue}>{formatRate(point.rate)}</span>}
                            <div
                                style={{ height: `${Math.max((point.rate / scaleMax) * BAR_MAX_HEIGHT_PERCENT, 2).toFixed(2)}%` }}
                                className={clsx(Bar, LevelFill[point.level])}
                            />
                        </div>
                    })
                }
            </div>
            <div aria-hidden="true" className={AxisRow}>
                {
                    chartPoints.map((point) => {
                        return <span key={point.date} className={clsx(AxisLabel, isToday(point.date) && AxisLabelToday)}>
                            {point.weekday}
                        </span>
                    })
                }
            </div>
        </div>

        <div className={ActionRow}>
            <button
                type="button"
                aria-expanded={isForecastOpen}
                onClick={() => setIsForecastOpen((prev) => !prev)}
                className={ActionButton}
            >
                {isForecastOpen ? "예보 접기" : `전체 예보 보기 (${series.length}일)`}
            </button>
            <a
                href={buildKakaoMapSearchUrl(mapKeyword)}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${target.name} 카카오맵에서 보기 (새 창)`}
                className={ActionButton}
            >
                지도에서 보기 ↗
            </a>
        </div>

        {/* 그래프의 표 버전 — 툴팁 없이도 모든 값을 읽을 수 있게 한다 */}
        {isForecastOpen && (
            <table className={ForecastTable}>
                <caption className="sr-only">{target.name} 일자별 혼잡도 예측</caption>
                <thead>
                    <tr className={TableHeadRow}>
                        <th scope="col" className={TableCell}>날짜</th>
                        <th scope="col" className={TableCell}>등급</th>
                        <th scope="col" className={clsx(TableCell, NumberCell)}>집중률</th>
                    </tr>
                </thead>
                <tbody>
                    {
                        series.map((point) => {
                            return <tr key={point.date} className={TableRow}>
                                <td className={TableCell}>{formatShortDate(point.date)} ({point.weekday})</td>
                                <td className={TableCell}>
                                    <span className={LevelCell}>
                                        <span aria-hidden="true" className={clsx(LevelDotBase, LevelFill[point.level])} />
                                        {point.level}
                                    </span>
                                </td>
                                <td className={clsx(TableCell, NumberCell)}>{formatRate(point.rate)}</td>
                            </tr>
                        })
                    }
                </tbody>
            </table>
        )}

        <div className={FooterNotes}>
            {/* 명세: 집중률은 예측값임을 고지한다. SB-03: 최대 제공 일수 문구는 안내 영역에 둔다 */}
            <p className={Muted}>
                집중률은 예측값이에요{hasMoreForecast && ` · 이 관광지는 최대 ${target.available_days}일까지 예보가 있어요`}
            </p>
            {payload.source && <p className={Muted}>{payload.source}</p>}
        </div>
    </div>
}
export default CrowdAttractionCard;
//style configuration
// 다른 대화 카드(대안 · 추천 · 지역 현황)와 같은 어두운 톤
const CardShell = clsx(
    "w-180 bg-[#333743]",
    "flex flex-col gap-3",
    "rounded-[12px]",
    "p-[22px_32px] box-border",
    "text-[13px] text-[#FFFFFF]"
);

const CardHeader = clsx(
    "flex items-start justify-between gap-3"
);

const TitleGroup = clsx(
    "flex flex-col gap-0.5 min-w-0"
);

const CardTitle = clsx(
    "truncate",
    "text-[20px] text-[#FFFFFF] font-medium"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);

const ChartPlot = clsx(
    "flex items-end gap-2",
    "h-28",
    "border-b border-[#63717A]"
);

// 막대보다 넓은 슬롯 전체가 호버·포커스 영역이다
const BarSlot = clsx(
    "group relative",
    "flex flex-1 flex-col items-center justify-end",
    "h-full",
    "rounded-[4px]",
    "outline-none focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-[#6FC1FC]"
);

const Bar = clsx(
    "w-full max-w-6",
    "rounded-t-[4px]",
    "transition-opacity",
    "group-hover:opacity-80 group-focus-visible:opacity-80"
);

const BarValue = clsx(
    "mb-1",
    "text-[11px] text-[#D8D8D8] tabular-nums"
);

const BarTooltip = clsx(
    "pointer-events-none absolute bottom-full z-10",
    "whitespace-nowrap",
    "rounded-[6px]",
    "bg-[#1A1C22]",
    "border border-[#63717A]",
    "px-2 py-1",
    "text-[11px] text-[#FFFFFF]",
    "opacity-0",
    "group-hover:opacity-100 group-focus-visible:opacity-100"
);

const TooltipAlign = {
    start: "left-0",
    center: "left-1/2 -translate-x-1/2",
    end: "right-0",
} as const;

const AxisRow = clsx(
    "flex gap-2",
    "pt-1"
);

const AxisLabel = clsx(
    "flex-1 text-center",
    "text-[11px] text-[#909090]"
);

const AxisLabelToday = clsx(
    "font-bold text-[#FFFFFF]"
);

const ActionRow = clsx(
    "flex flex-wrap gap-2"
);

// 대안 · 추천 카드의 ActionButton 과 같은 모양
const ActionButton = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-3 py-1.5",
    "text-[12px] text-[#FFFFFF] font-normal",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]",
    "cursor-pointer"
);

const ForecastTable = clsx(
    "w-full border-collapse",
    "text-[12px] text-[#D8D8D8]"
);

const TableHeadRow = clsx(
    "border-b border-[#63717A]",
    "text-[#909090]"
);

const TableRow = clsx(
    "border-b border-[#63717A] last:border-b-0"
);

const TableCell = clsx(
    "py-1.5 text-left font-normal"
);

const NumberCell = clsx(
    "text-right tabular-nums"
);

const LevelCell = clsx(
    "inline-flex items-center gap-1.5"
);

const FooterNotes = clsx(
    "flex flex-col gap-0.5"
);
