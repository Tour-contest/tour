//react
import { useState } from "react";
//side components
import VisitorsBarChart from "./VisitorsBarChart";
//side features
import {
    SEGMENT_GRADIENT,
    SEGMENT_LABEL,
    VISITOR_SEGMENTS,
    formatCount,
    formatDataThrough,
    formatWeekLabel,
    groupByWeek,
    hasBreakdown,
    type VisitorSegment,
} from "./visitorsVisual";
//style
import clsx from "clsx";

type AreaVisitorsCardNeedProps = {
    payload: AreaVisitorsData;
};

// 지역 방문자 추세 — 주별 막대 (명세). 그래프는 VisitorsBarChart(d3), 범례·표·안내는 여기서.
// 약 75일 지연된 값이라 "최근" 대신 data_through 를 반드시 같이 보인다
const AreaVisitorsCard = ({ payload } : AreaVisitorsCardNeedProps) => {
    const [isTableOpen, setIsTableOpen] = useState<boolean>(false);

    const weeks = groupByWeek(payload.items);
    const isStacked = hasBreakdown(weeks);
    const title = `${payload.signgu_nm ?? "지역"} 방문자 추세`;

    // 외국인 값이 하나라도 있는 주가 있을 때만 표 열에 올린다
    const segments: VisitorSegment[] = isStacked
        ? VISITOR_SEGMENTS.filter((segment) => weeks.some((week) => week[segment] !== null))
        : [];

    return <div className={Card}>
        <h4 className={Title}>{title}</h4>

        {weeks.length === 0 ? (
            <p className={Muted}>{payload.note ?? "방문자 자료가 없어요"}</p>
        ) : (
            <>
                <VisitorsBarChart title={title} weeks={weeks} isStacked={isStacked} segments={segments} />

                {/* 범례 색칩은 막대 조각과 같은 세로 그라데이션 */}
                {segments.length > 0 && (
                    <ul className={Legend}>
                        {
                            segments.map((segment) => {
                                const [top, bottom] = SEGMENT_GRADIENT[segment];
                                return <li key={segment} className={LegendItem}>
                                    <span aria-hidden="true" className={LegendSwatch} style={{ backgroundImage: `linear-gradient(to bottom, ${top}, ${bottom})` }} />
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
};
export default AreaVisitorsCard;
//style configuration
// 다른 대화 카드와 같은 어두운 톤. TODO: 디테일 단계에서 개발자와 함께 조정
const Card = clsx(
    "flex flex-col gap-3",
    "rounded-[12px]",
    "bg-[#333743]",
    "p-[22px_32px] box-border",
    "text-[13px] text-[#FFFFFF]"
);

const Title = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);

const Legend = clsx(
    "flex flex-wrap gap-4"
);

const LegendItem = clsx(
    "inline-flex items-center gap-2",
    "text-[16px] text-[#D8D8D8] font-normal"
);

// 막대와 같은 알약 모양의 작은 색칩
const LegendSwatch = clsx(
    "h-4 w-3 shrink-0 rounded-full"
);

const ActionRow = clsx(
    "flex flex-wrap gap-2"
);

const ActionButton = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-3 py-1.5",
    "text-[12px] text-[#FFFFFF] font-normal",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]",
    "cursor-pointer"
);

const DataTable = clsx(
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

const FooterNotes = clsx(
    "flex flex-col gap-0.5"
);
