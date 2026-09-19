import { useId } from "react";
import { area, curveMonotoneX, line, max, scaleLinear, scalePoint } from "d3";
import clsx from "clsx";

type DailyCallsChartNeedProps = {
    daily: ApiCallDaily[];
};

// viewBox 좌표로 그리고 CSS 로 카드 폭에 맞춘다
const CHART_WIDTH = 640;
const CHART_HEIGHT = 220;
const MARGIN = { top: 16, right: 16, bottom: 28, left: 40 };
const PLOT_WIDTH = CHART_WIDTH - MARGIN.left - MARGIN.right;
const PLOT_HEIGHT = CHART_HEIGHT - MARGIN.top - MARGIN.bottom;
const Y_TICK_COUNT = 5;

const LINE_COLOR = "#6FC1FC";

type DailyPoint = {
    date: string;
    total: number;
    real: number;
    cached: number;
};

const formatDateLabel = (date: string) => {
    const [, month, day] = date.split("-");
    return `${Number(month)}/${Number(day)}`;
};

// 일자별 호출 추이 — 부드러운 곡선 + 아래 그라데이션 영역 + 점선 격자 + 일자 점 (개발자 시안).
// d3 는 눈금·경로 계산만 하고 그리기는 React 가 한다. 값은 실제 호출 + 절약분 합계이며 툴팁에 내역을 둔다
const DailyCallsChart = ({ daily } : DailyCallsChartNeedProps) => {
    const gradientId = useId();

    const points: DailyPoint[] = daily.map((day) => ({ date: day.date, total: day.real + day.cached, real: day.real, cached: day.cached }));

    if (points.length === 0) return <p className={Muted}>호출 기록이 없습니다</p>;

    const x = scalePoint<string>().domain(points.map((point) => point.date)).range([0, PLOT_WIDTH]);
    const y = scaleLinear().domain([0, max(points, (point) => point.total) ?? 0]).nice().range([PLOT_HEIGHT, 0]);
    const yTicks = y.ticks(Y_TICK_COUNT);

    const drawArea = area<DailyPoint>()
        .x((point) => x(point.date) ?? 0)
        .y0(PLOT_HEIGHT)
        .y1((point) => y(point.total))
        .curve(curveMonotoneX);

    const drawLine = line<DailyPoint>()
        .x((point) => x(point.date) ?? 0)
        .y((point) => y(point.total))
        .curve(curveMonotoneX);

    const summary = points.map((point) => `${formatDateLabel(point.date)} ${point.total}건`).join(", ");

    return <svg
        viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`}
        role="img"
        aria-label={`일자별 호출 추이 — ${summary}`}
        className={Chart}
    >
        <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={LINE_COLOR} stopOpacity={0.35} />
                <stop offset="100%" stopColor={LINE_COLOR} stopOpacity={0} />
            </linearGradient>
        </defs>

        <g transform={`translate(${MARGIN.left} ${MARGIN.top})`}>
            {/* 격자: 가로는 y 눈금, 세로는 일자 */}
            {
                yTicks.map((tick) => {
                    return <g key={`y-${tick}`}>
                        <line x1={0} x2={PLOT_WIDTH} y1={y(tick)} y2={y(tick)} className={GridLine} />
                        <text x={-8} y={y(tick)} textAnchor="end" dominantBaseline="middle" className={TickLabel}>{tick}</text>
                    </g>
                })
            }
            {
                points.map((point) => {
                    return <line key={`x-${point.date}`} x1={x(point.date)} x2={x(point.date)} y1={0} y2={PLOT_HEIGHT} className={GridLine} />
                })
            }

            {/* 곡선은 점이 2개 이상일 때만 이어진다 */}
            {points.length > 1 && (
                <>
                    <path d={drawArea(points) ?? undefined} fill={`url(#${gradientId})`} />
                    <path d={drawLine(points) ?? undefined} fill="none" stroke={LINE_COLOR} strokeWidth={2} strokeLinejoin="round" />
                </>
            )}

            {
                points.map((point) => {
                    return <g key={point.date} tabIndex={0} className={PointGroup}>
                        <title>{`${formatDateLabel(point.date)} · 총 ${point.total}건 (실제 ${point.real} · 절약 ${point.cached})`}</title>
                        <circle cx={x(point.date)} cy={y(point.total)} r={4} fill="#333743" stroke={LINE_COLOR} strokeWidth={2} />
                        <text x={x(point.date)} y={PLOT_HEIGHT + 18} textAnchor="middle" className={TickLabel}>
                            {formatDateLabel(point.date)}
                        </text>
                    </g>
                })
            }
        </g>
    </svg>
}
export default DailyCallsChart;
//style configuration
// 어두운 카드(#333743) 위에 그린다: 격자 #3A3D47 · 눈금 #909090 · 선 #6FC1FC
const Chart = clsx(
    "w-full h-auto"
);

const GridLine = clsx(
    "stroke-[#3A3D47] [stroke-dasharray:4_4]"
);

const TickLabel = clsx(
    "fill-[#909090] text-[11px] tabular-nums"
);

const PointGroup = clsx(
    "outline-none",
    "hover:opacity-80 focus-visible:opacity-80"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);
