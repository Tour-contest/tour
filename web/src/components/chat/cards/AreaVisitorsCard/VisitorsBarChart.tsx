//react
import { useEffect, useId, useRef } from "react";
//d3
import { max, scaleBand, scaleLinear, select } from "d3";
//side features
import {
    SEGMENT_GRADIENT,
    SEGMENT_LABEL,
    TOTAL_GRADIENT,
    formatCompactCount,
    formatCount,
    formatWeekLabel,
    type VisitorSegment,
    type VisitorWeek,
} from "./visitorsVisual";

type VisitorsBarChartNeedProps = {
    title: string;
    weeks: VisitorWeek[];
    // 현지인·외지인 구분을 쌓아 그릴 수 있는지 (모든 주에 두 값이 있을 때)
    isStacked: boolean;
    // 쌓는 순서 = 범례 순서
    segments: VisitorSegment[];
};

// 글자를 실제 픽셀 크기(16px)로 두기 위해 viewBox 로 늘리지 않고, 카드 폭을 재서 그 픽셀 좌표로 그린다
const FALLBACK_WIDTH = 640;
const AXIS_FONT_SIZE = 16;
// x 축 라벨은 막대 밑선에서 이만큼 아래에 놓는다 (글자 기준선까지).
// 아래 여백과 전체 높이를 여기서 계산하므로 이 값만 바꾸면 라벨이 잘리지 않고 막대 높이도 그대로다
const AXIS_LABEL_OFFSET = 30;
const PLOT_HEIGHT = 162;
const MARGIN = { top: 48, right: 8, bottom: AXIS_LABEL_OFFSET + Math.ceil(AXIS_FONT_SIZE * 0.4), left: 52 };
const CHART_HEIGHT = MARGIN.top + PLOT_HEIGHT + MARGIN.bottom;
const Y_TICK_COUNT = 4;
// 나란히 선 막대의 위 모서리 반지름
const BAR_RADIUS = 4;

// 시안: 고른 막대만 또렷하고 나머지는 흐리게 · 말풍선 · 점선 안내선 · y 눈금 점선
const DIM_OPACITY = 0.4;
const ACCENT_COLOR = "#6FC1FC";
const GRID_COLOR = "#3A3D47";
const AXIS_LABEL_COLOR = "#909090";
const TOOLTIP_TEXT_COLOR = "#1A1C22";

// 구분이 없을 때 쓰는 가짜 키. 합계 하나를 현지인 조각과 같은 그라데이션으로 그린다
const TOTAL_KEY = "total";
type BarKey = VisitorSegment | typeof TOTAL_KEY;

const buildTooltip = (week: VisitorWeek, isStacked: boolean) => {
    const parts = [`${formatWeekLabel(week.weekStart)} 주 ${formatCount(week.total)}`];
    if (isStacked) {
        for (const segment of ["local", "outsider", "foreigner"] as const) {
            const value = week[segment];
            if (value !== null) parts.push(`${SEGMENT_LABEL[segment]} ${formatCount(value)}`);
        }
    }
    if (week.days < 7) parts.push(`${week.days}일치`);
    return parts.join(" · ");
};

// 주별 방문자 막대 (명세: 주별 막대). d3 가 <svg> 안을 직접 그린다.
// 주마다 현지인 · 외지인 · 외국인 막대를 나란히 세우고(그라데이션), 고른 주만 또렷하게 + 말풍선(합계) + 점선 안내선.
// 처음엔 가장 최근 주가 골라져 있고, 막대에 올리거나 포커스하면 그 주로 바뀐다
const VisitorsBarChart = ({ title, weeks, isStacked, segments } : VisitorsBarChartNeedProps) => {
    const svgRef = useRef<SVGSVGElement | null>(null);
    const idPrefix = useId();

    useEffect(() => {
        const svgElement = svgRef.current;
        if (!svgElement || weeks.length === 0) return;

        const draw = () => {
            const width = svgElement.clientWidth || FALLBACK_WIDTH;
            const plotWidth = width - MARGIN.left - MARGIN.right;
            const plotHeight = PLOT_HEIGHT;

            const svg = select(svgElement).attr("width", width).attr("height", CHART_HEIGHT);
            svg.selectAll("*").remove();

            // 조각별 세로 그라데이션 (같은 페이지에 카드가 여럿이라 id 는 useId 로 유일하게)
            const keys: BarKey[] = isStacked ? segments : [TOTAL_KEY];
            const gradientId = (key: BarKey) => `${idPrefix}-${key}`;
            const defs = svg.append("defs");
            for (const key of keys) {
                const [top, bottom] = key === TOTAL_KEY ? TOTAL_GRADIENT : SEGMENT_GRADIENT[key];
                const gradient = defs.append("linearGradient").attr("id", gradientId(key)).attr("x1", 0).attr("y1", 0).attr("x2", 0).attr("y2", 1);
                gradient.append("stop").attr("offset", "0%").attr("stop-color", top);
                gradient.append("stop").attr("offset", "100%").attr("stop-color", bottom);
            }

            // 나란히 그리므로 눈금 최대는 합계가 아니라 조각 하나의 최대값
            const valueOf = (week: VisitorWeek, key: BarKey) => (key === TOTAL_KEY ? week.total : week[key] ?? 0);
            const maxValue = max(weeks, (week) => max(keys, (key) => valueOf(week, key)) ?? 0) ?? 0;
            const x = scaleBand<string>().domain(weeks.map((week) => week.weekStart)).range([0, plotWidth]).padding(0.3);
            // 주 안에서 구분별 막대 자리
            const xInner = scaleBand<BarKey>().domain(keys).range([0, x.bandwidth()]).padding(0.2);
            const y = scaleLinear().domain([0, maxValue]).range([plotHeight, 0]).nice();
            const barRadius = Math.min(BAR_RADIUS, xInner.bandwidth() / 2);

            const plot = svg.append("g").attr("transform", `translate(${MARGIN.left} ${MARGIN.top})`);

            // y 눈금: 점선 격자 + 압축 표기 라벨 (0 · 2만 · 4만 …). 글자는 16px · 보통 굵기 · 앱 글꼴
            const ticks = y.ticks(Y_TICK_COUNT);
            const grid = plot.selectAll<SVGGElement, number>("g.tick").data(ticks).join("g").attr("class", "tick");
            grid.append("line")
                .attr("x1", 0).attr("x2", plotWidth)
                .attr("y1", (tick) => y(tick)).attr("y2", (tick) => y(tick))
                .attr("stroke", GRID_COLOR).attr("stroke-dasharray", "2 3");
            grid.append("text")
                .attr("x", -10).attr("y", (tick) => y(tick))
                .attr("text-anchor", "end").attr("dominant-baseline", "middle")
                .attr("font-size", AXIS_FONT_SIZE).attr("font-weight", 400).attr("font-family", "inherit")
                .attr("fill", AXIS_LABEL_COLOR)
                .text((tick) => (tick === 0 ? "0" : formatCompactCount(tick)));

            // 막대 묶음: 주마다 구분별 막대를 나란히 세운다 (위 모서리만 둥글게 — 바닥선에 닿는 아래는 각지게 살짝 넘겨 그린다)
            const barGroups = plot.selectAll<SVGGElement, VisitorWeek>("g.bar")
                .data(weeks)
                .join("g")
                .attr("class", "bar")
                .attr("opacity", DIM_OPACITY);

            barGroups.selectAll<SVGRectElement, BarKey>("rect.segment")
                .data((week) => keys.map((key) => ({ key, week })))
                .join("rect")
                .attr("class", "segment")
                .attr("data-key", (d) => d.key)
                .attr("x", (d) => (x(d.week.weekStart) ?? 0) + (xInner(d.key) ?? 0))
                .attr("y", (d) => y(valueOf(d.week, d.key)))
                .attr("width", xInner.bandwidth())
                .attr("height", (d) => Math.max(plotHeight - y(valueOf(d.week, d.key)), 0) + barRadius)
                .attr("rx", barRadius)
                .attr("fill", (d) => `url(#${gradientId(d.key)})`);

            // 아래로 넘긴 둥근 부분은 바닥선 아래를 가려서 각지게 보인다
            plot.append("rect")
                .attr("class", "baseline-mask")
                .attr("x", -1).attr("y", plotHeight + 0.5)
                .attr("width", plotWidth + 2).attr("height", barRadius + 1)
                .attr("fill", "#333743");

            // x 축 라벨 (주 시작일)
            plot.selectAll<SVGTextElement, VisitorWeek>("text.axis")
                .data(weeks)
                .join("text")
                .attr("class", "axis")
                .attr("x", (week) => (x(week.weekStart) ?? 0) + x.bandwidth() / 2)
                .attr("y", plotHeight + AXIS_LABEL_OFFSET)
                .attr("text-anchor", "middle")
                .attr("font-size", AXIS_FONT_SIZE).attr("font-weight", 400).attr("font-family", "inherit")
                .attr("fill", AXIS_LABEL_COLOR)
                .text((week) => formatWeekLabel(week.weekStart));

            // 고른 주의 안내선(점선)과 말풍선. 값이 바뀔 때 위치·글자만 갱신한다
            const guide = plot.append("line").attr("class", "guide")
                .attr("x1", 0).attr("x2", plotWidth)
                .attr("stroke", ACCENT_COLOR).attr("stroke-dasharray", "4 3");
            const bubble = plot.append("g").attr("class", "bubble");
            const bubbleRect = bubble.append("rect").attr("rx", 6).attr("fill", ACCENT_COLOR);
            const bubbleTail = bubble.append("path").attr("fill", ACCENT_COLOR);
            const bubbleText = bubble.append("text")
                .attr("text-anchor", "middle").attr("dominant-baseline", "middle")
                .attr("font-size", 14).attr("font-weight", 600).attr("font-family", "inherit")
                .attr("fill", TOOLTIP_TEXT_COLOR);

            const highlight = (index: number) => {
                const week = weeks[index];
                if (!week) return;

                barGroups.attr("opacity", (_, i) => (i === index ? 1 : DIM_OPACITY))
                    .attr("data-selected", (_, i) => (i === index ? "true" : null));

                // 안내선·말풍선은 그 주에서 가장 높은 막대 위에
                const barTop = y(max(keys, (key) => valueOf(week, key)) ?? 0);
                const centerX = (x(week.weekStart) ?? 0) + x.bandwidth() / 2;
                guide.attr("y1", barTop).attr("y2", barTop);

                const label = formatCount(week.total);
                // jsdom 엔 getBBox 가 없어 글자 수로 폭을 어림한다 (14px 기준 숫자·쉼표 8px 안팎)
                const bubbleWidth = label.length * 8 + 20;
                const bubbleHeight = 26;
                const bubbleX = Math.min(Math.max(centerX - bubbleWidth / 2, 0), plotWidth - bubbleWidth);
                const bubbleY = barTop - bubbleHeight - 12;
                bubbleRect.attr("x", bubbleX).attr("y", bubbleY).attr("width", bubbleWidth).attr("height", bubbleHeight);
                bubbleTail.attr("d", `M${centerX - 5} ${bubbleY + bubbleHeight} L${centerX} ${bubbleY + bubbleHeight + 6} L${centerX + 5} ${bubbleY + bubbleHeight} Z`);
                bubbleText.attr("x", bubbleX + bubbleWidth / 2).attr("y", bubbleY + bubbleHeight / 2 + 1).text(label);
            };

            // 주마다 보이지 않는 세로 띠를 얹어 호버·포커스 영역으로 쓴다. 브라우저 기본 툴팁(<title>)엔 구분 값까지
            plot.selectAll<SVGRectElement, VisitorWeek>("rect.hit")
                .data(weeks)
                .join("rect")
                .attr("class", "hit")
                .attr("fill", "transparent")
                .attr("tabindex", 0)
                .attr("x", (week) => x(week.weekStart) ?? 0)
                .attr("y", -MARGIN.top)
                .attr("width", x.bandwidth())
                .attr("height", plotHeight + MARGIN.top)
                .on("mouseenter focus", (_, week) => highlight(weeks.indexOf(week)))
                .append("title")
                .text((week) => buildTooltip(week, isStacked));

            // 처음엔 가장 최근 주
            highlight(weeks.length - 1);
        };

        draw();

        // 카드 폭(사이드바 너비 조절 등)이 바뀌면 픽셀 좌표로 다시 그린다
        if (typeof ResizeObserver === "undefined") return;
        const observer = new ResizeObserver(() => draw());
        observer.observe(svgElement);
        return () => observer.disconnect();
    }, [weeks, isStacked, segments, idPrefix]);

    return <svg
        ref={svgRef}
        height={CHART_HEIGHT}
        role="img"
        aria-label={`${title} — ${weeks.map((week) => buildTooltip(week, false)).join(", ")}`}
        className={Chart}
    />
};
export default VisitorsBarChart;
//style configuration
const Chart = "block w-full";
