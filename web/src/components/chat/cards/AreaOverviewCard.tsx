import { arc, pie } from "d3";
import type { PieArcDatum } from "d3";
import clsx from "clsx";
import { LevelDotBase, LevelFill, formatDateLabel } from "./crowdVisual";

type AreaOverviewCardNeedProps = {
    payload: AreaOverviewData;
};

type LevelSlice = {
    level: CrowdLevel;
    count: number;
};

// 시계 방향으로 한적 → 보통 → 혼잡. 값 크기로 재정렬하지 않아 카드끼리 같은 순서로 읽힌다
const LEVEL_ORDER: CrowdLevel[] = ["한적", "보통", "혼잡"];

const SUMMARY_KEY: Record<CrowdLevel, keyof AreaCrowdSummary> = {
    한적: "quiet",
    보통: "normal",
    혼잡: "crowded",
};

// crowdVisual 의 상태 팔레트와 같은 값. SVG 는 클래스가 아니라 fill 속성으로 칠한다
const LEVEL_COLOR: Record<CrowdLevel, string> = {
    한적: "#0ca30c",
    보통: "#fab219",
    혼잡: "#d03b3b",
};

const CHART_SIZE = 120;
const RING_THICKNESS = 26;
const RADIUS = CHART_SIZE / 2;

const buildSlices = (summary: AreaCrowdSummary): LevelSlice[] => {
    return LEVEL_ORDER.map((level) => ({ level, count: summary[SUMMARY_KEY[level]] ?? 0 }));
};

// 0곳인 등급은 조각을 만들지 않는다 — padAngle 때문에 빈 조각이 틈으로 남는다
const layoutPie = pie<LevelSlice>()
    .value((slice) => slice.count)
    .sort(null)
    .padAngle(0.02);

const drawArc = arc<PieArcDatum<LevelSlice>>()
    .innerRadius(RADIUS - RING_THICKNESS)
    .outerRadius(RADIUS)
    .cornerRadius(2);

// 지역 전체 혼잡 현황 (SB-05). 도넛이 비율을, 아래 칩이 등급별 곳 수를 전한다.
// 색만으로 읽게 하지 않도록 칩에 등급 글자와 숫자를 함께 두고, 조각에는 툴팁(title)을 단다
const AreaOverviewCard = ({ payload } : AreaOverviewCardNeedProps) => {
    const { signgu_nm, date, summary, coverage, source, message } = payload;

    const slices = summary ? buildSlices(summary) : [];
    const total = slices.reduce((sum, slice) => sum + slice.count, 0);
    const arcs = layoutPie(slices.filter((slice) => slice.count > 0));
    const chartLabel = slices.map((slice) => `${slice.level} ${slice.count}곳`).join(", ");

    return <div className={Card}>
        <p className={Title}>{signgu_nm} {formatDateLabel(date)} 현황</p>

        {total > 0 ? (
            <svg
                viewBox={`0 0 ${CHART_SIZE} ${CHART_SIZE}`}
                role="img"
                aria-label={`${signgu_nm} 등급별 관광지 수 — ${chartLabel}`}
                className={Chart}
            >
                <g transform={`translate(${RADIUS} ${RADIUS})`}>
                    {
                        arcs.map((slice) => {
                            // svg <title> 은 React 가 자식을 하나만 그리므로 문자열 하나로 합친다
                            const tooltip = `${slice.data.level} ${slice.data.count}곳 · ${Math.round((slice.data.count / total) * 100)}%`;

                            return <path key={slice.data.level} d={drawArc(slice) ?? undefined} fill={LEVEL_COLOR[slice.data.level]}>
                                <title>{tooltip}</title>
                            </path>
                        })
                    }
                </g>
            </svg>
        ) : (
            <p className={Muted}>{message ?? "집계된 관광지가 없어요"}</p>
        )}

        {summary && (
            <ul className={ChipRow}>
                {
                    slices.map((slice) => {
                        return <li key={slice.level} className={ChipItem}>
                            <span className={Chip}>
                                <span aria-hidden="true" className={clsx(LevelDotBase, LevelFill[slice.level])} />
                                {slice.level}
                            </span>
                            <span className={ChipCount}>{slice.count}곳</span>
                        </li>
                    })
                }
            </ul>
        )}

        {coverage && (
            <p className={Muted}>관광정보 {coverage.tourapi_total}곳 중 집중률 보유 {coverage.with_crowd_data}곳</p>
        )}
        {source && <p className={Muted}>{source}</p>}
    </div>
}
export default AreaOverviewCard;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지금은 구조만
const Card = clsx(
    "flex flex-col gap-3",
    "border border-[#e5e4e7] rounded-[12px]",
    "p-4",
    "text-[13px]"
);

const Title = clsx(
    "text-[14px] font-bold"
);

const Chart = clsx(
    "self-center",
    "size-[120px]"
);

const ChipRow = clsx(
    "flex flex-wrap items-center justify-center gap-3"
);

const ChipItem = clsx(
    "flex items-center gap-1"
);

const Chip = clsx(
    "inline-flex items-center gap-1 shrink-0",
    "border border-[#e5e4e7] rounded-full",
    "bg-white",
    "px-2 py-0.5",
    "text-[12px]"
);

const ChipCount = clsx(
    "font-semibold"
);

const Muted = clsx(
    "text-[12px] text-[#6b6375]"
);
