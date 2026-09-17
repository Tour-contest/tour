import { useState } from "react";
import { max, scaleBand, scaleLinear } from "d3";
import clsx from "clsx";
import {
    SEGMENT_COLOR,
    SEGMENT_LABEL,
    TOTAL_COLOR,
    VISITOR_SEGMENTS,
    formatCompactCount,
    formatCount,
    formatDataThrough,
    formatWeekLabel,
    groupByWeek,
    hasBreakdown,
    type VisitorSegment,
    type VisitorWeek,
} from "./visitorsVisual";

type AreaVisitorsCardNeedProps = {
    payload: AreaVisitorsData;
};

// 차트는 viewBox 좌표로 그리고 CSS 로 카드 폭에 맞춘다
const CHART_WIDTH = 320;
const CHART_HEIGHT = 150;
const MARGIN = { top: 18, right: 4, bottom: 18, left: 4 };
const PLOT_WIDTH = CHART_WIDTH - MARGIN.left - MARGIN.right;
const PLOT_HEIGHT = CHART_HEIGHT - MARGIN.top - MARGIN.bottom;

const buildTooltip = (week: VisitorWeek, isStacked: boolean) => {
    const parts = [`${formatWeekLabel(week.weekStart)} 주 ${formatCount(week.total)}`];
    if (isStacked) {
        for (const segment of VISITOR_SEGMENTS) {
            const value = week[segment];
            if (value !== null) parts.push(`${SEGMENT_LABEL[segment]} ${formatCount(value)}`);
        }
    }
    if (week.days < 7) parts.push(`${week.days}일치`);
    return parts.join(" · ");
};

// 지역 방문자 추세 — 주별 막대 (명세). d3 는 눈금 계산만 하고 그리기는 React 가 한다.
// 약 75일 지연된 값이라 "최근" 대신 data_through 를 반드시 같이 보인다
const AreaVisitorsCard = ({ payload } : AreaVisitorsCardNeedProps) => {
    const [isTableOpen, setIsTableOpen] = useState<boolean>(false);

    const weeks = groupByWeek(payload.items);
    const isStacked = hasBreakdown(weeks);
    const title = `${payload.signgu_nm ?? "지역"} 방문자 추세`;

    const totals = weeks.map((week) => week.total);
    const maxTotal = max(totals) ?? 0;
    const minTotal = weeks.length > 0 ? Math.min(...totals) : 0;

    const x = scaleBand<string>().domain(weeks.map((week) => week.weekStart)).range([0, PLOT_WIDTH]).padding(0.3);
    const y = scaleLinear().domain([0, maxTotal]).range([PLOT_HEIGHT, 0]).nice();

    // 외국인 값이 하나라도 있는 주가 있을 때만 범례에 올린다
    const segments: VisitorSegment[] = isStacked
        ? VISITOR_SEGMENTS.filter((segment) => weeks.some((week) => week[segment] !== null))
        : [];

    return <div className={Card}>
        <p className={Title}>{title}</p>

        {weeks.length === 0 ? (
            <p className={Muted}>{payload.note ?? "방문자 자료가 없어요"}</p>
        ) : (
            <>
                <svg
                    viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`}
                    role="img"
                    aria-label={`${title} — ${weeks.map((week) => buildTooltip(week, false)).join(", ")}`}
                    className={Chart}
                >
                    <g transform={`translate(${MARGIN.left} ${MARGIN.top})`}>
                        <line x1={0} x2={PLOT_WIDTH} y1={PLOT_HEIGHT} y2={PLOT_HEIGHT} stroke="#c3c2b7" />
                        {
                            weeks.map((week) => {
                                const barX = x(week.weekStart) ?? 0;
                                const barWidth = x.bandwidth();
                                // 모든 막대에 숫자를 달지 않고 최고·최저만 표시한다. 나머지는 툴팁과 표 보기로 읽는다
                                const isExtreme = maxTotal !== minTotal && (week.total === maxTotal || week.total === minTotal);
                                const tooltip = buildTooltip(week, isStacked);

                                // 쌓기: 현지인 → 외지인 → 외국인 순으로 바닥부터
                                let cursor = 0;
                                const stackedRects = isStacked
                                    ? segments.flatMap((segment) => {
                                        const value = week[segment] ?? 0;
                                        if (value <= 0) return [];
                                        const rect = { segment, y: y(cursor + value), height: y(cursor) - y(cursor + value) };
                                        cursor += value;
                                        return [rect];
                                    })
                                    : [];

                                return <g key={week.weekStart} tabIndex={0} className={BarGroup}>
                                    <title>{tooltip}</title>
                                    {isStacked ? (
                                        stackedRects.map((rect) => (
                                            <rect
                                                key={rect.segment}
                                                x={barX}
                                                y={rect.y}
                                                width={barWidth}
                                                height={Math.max(rect.height, 0)}
                                                fill={SEGMENT_COLOR[rect.segment]}
                                            />
                                        ))
                                    ) : (
                                        <rect
                                            x={barX}
                                            y={y(week.total)}
                                            width={barWidth}
                                            height={Math.max(PLOT_HEIGHT - y(week.total), 1)}
                                            rx={3}
                                            fill={TOTAL_COLOR}
                                        />
                                    )}
                                    {isExtreme && (
                                        <text x={barX + barWidth / 2} y={y(week.total) - 5} textAnchor="middle" className={BarValue}>
                                            {formatCompactCount(week.total)}
                                        </text>
                                    )}
                                    <text x={barX + barWidth / 2} y={PLOT_HEIGHT + 13} textAnchor="middle" className={AxisLabel}>
                                        {formatWeekLabel(week.weekStart)}
                                    </text>
                                </g>
                            })
                        }
                    </g>
                </svg>

                {segments.length > 0 && (
                    <ul className={Legend}>
                        {
                            segments.map((segment) => {
                                return <li key={segment} className={LegendItem}>
                                    <span aria-hidden="true" className={LegendDot} style={{ backgroundColor: SEGMENT_COLOR[segment] }} />
                                    {SEGMENT_LABEL[segment]}
                                </li>
                            })
                        }
                    </ul>
                )}

                <div className={ActionRow}>
                    <button
                        type="button"
                        aria-expanded={isTableOpen}
                        onClick={() => setIsTableOpen((prev) => !prev)}
                        className={ActionButton}
                    >
                        {isTableOpen ? "표 접기" : `주별 수치 보기 (${weeks.length}주)`}
                    </button>
                </div>

                {/* 그래프의 표 버전 — 툴팁 없이도 모든 값을 읽을 수 있게 한다 */}
                {isTableOpen && (
                    <table className={DataTable}>
                        <caption className="sr-only">{title} 주별 방문자 수</caption>
                        <thead>
                            <tr className={TableHeadRow}>
                                <th scope="col" className={TableCell}>주 (시작일)</th>
                                <th scope="col" className={clsx(TableCell, NumberCell)}>합계</th>
                                {segments.map((segment) => (
                                    <th key={segment} scope="col" className={clsx(TableCell, NumberCell)}>{SEGMENT_LABEL[segment]}</th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {
                                weeks.map((week) => {
                                    return <tr key={week.weekStart} className={TableRow}>
                                        <td className={TableCell}>
                                            {formatWeekLabel(week.weekStart)}{week.days < 7 && <span className={Muted}> ({week.days}일)</span>}
                                        </td>
                                        <td className={clsx(TableCell, NumberCell)}>{formatCount(week.total)}</td>
                                        {segments.map((segment) => (
                                            <td key={segment} className={clsx(TableCell, NumberCell)}>
                                                {week[segment] === null ? "-" : formatCount(week[segment])}
                                            </td>
                                        ))}
                                    </tr>
                                })
                            }
                        </tbody>
                    </table>
                )}
            </>
        )}

        <div className={FooterNotes}>
            <p className={Muted}>{formatDataThrough(payload.data_through)}{payload.note && ` · ${payload.note}`}</p>
            {payload.partial && <p className={Muted}>일부 날짜가 비어 있어요. 다시 조회하면 채워져요</p>}
        </div>
    </div>
}
export default AreaVisitorsCard;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지금은 구조만
const Card = clsx(
    "flex flex-col gap-3",
    "border border-[#e5e4e7] rounded-[12px]",
    "bg-white",
    "p-4 box-border",
    "text-[13px]"
);

const Title = clsx(
    "text-[15px] font-bold"
);

const Muted = clsx(
    "text-[12px] text-[#6b6375]"
);

const Chart = clsx(
    "w-full h-auto"
);

// 막대 묶음 전체가 호버·포커스 영역. 브라우저 기본 툴팁(title)이 값을 보여준다
const BarGroup = clsx(
    "outline-none",
    "hover:opacity-80 focus-visible:opacity-80"
);

const BarValue = clsx(
    "fill-[#52514e] text-[11px] tabular-nums"
);

const AxisLabel = clsx(
    "fill-[#6b6375] text-[10px]"
);

const Legend = clsx(
    "flex flex-wrap gap-3"
);

const LegendItem = clsx(
    "inline-flex items-center gap-1",
    "text-[12px] text-[#52514e]"
);

const LegendDot = clsx(
    "size-2 shrink-0 rounded-full"
);

const ActionRow = clsx(
    "flex flex-wrap gap-2"
);

const ActionButton = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "px-3 py-1.5",
    "text-[12px]",
    "hover:bg-[#f4f3ec]"
);

const DataTable = clsx(
    "w-full border-collapse",
    "text-[12px]"
);

const TableHeadRow = clsx(
    "border-b border-[#e1e0d9]",
    "text-[#6b6375]"
);

const TableRow = clsx(
    "border-b border-[#e1e0d9] last:border-b-0"
);

const TableCell = clsx(
    "py-1.5 text-left font-normal"
);

const NumberCell = clsx(
    "text-right tabular-nums"
);

const FooterNotes = clsx(
    "flex flex-col gap-0.5"
);
