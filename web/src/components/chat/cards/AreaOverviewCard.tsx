import { arc, pie } from "d3";
import type { PieArcDatum } from "d3";
import clsx from "clsx";
import { LevelDotBase, LevelFill, formatDateLabel } from "./utils/crowdVisual";

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
    한적: "#15B836",
    보통: "#D3A418",
    혼잡: "#B84B15",
};

const BADGE_BORDER_COLOR: Record<CrowdLevel, string> = {
    한적: "border-[#15B836]",
    보통: "border-[#D3A418]",
    혼잡: "border-[#B84B15]",
};

const LABEL_COLOR: Record<CrowdLevel, string> = {
    한적: "text-[#15B836]",
    보통: "text-[#D3A418]",
    혼잡: "text-[#B84B15]",
};

const CHART_SIZE = 100;
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
        <h4 className={Title}>{signgu_nm} {formatDateLabel(date)} 현황</h4>
        <div className="flex flex-col gap-8 items-center">
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
                                <span className={clsx(BADGE_BORDER_COLOR[slice.level], LABEL_COLOR[slice.level] ,Chip)}>
                                    <span aria-hidden="true" className={clsx(LevelDotBase, LevelFill[slice.level])} />
                                    {slice.level}
                                </span>
                                <span className={ChipCount}>{slice.count}곳</span>
                            </li>
                        })
                    }
                </ul>
            )}
        </div>
        <div>
            { coverage && <p className={Muted}>관광정보 {coverage.tourapi_total}곳 중 집중률 보유 {coverage.with_crowd_data}곳</p> }
            { source && <p className={Muted}>{source}</p> }
        </div>
    </div>
}
export default AreaOverviewCard;
//style configuration
const Card = clsx(
    "w-180 bg-[#333743]",
    "flex flex-col gap-7.5",
    "rounded-[12px]",
    "p-[22px_32px] box-border",
    "text-[14px] font-normal"
);

const Title = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const Chart = clsx(
    "self-center",
    "size-40"
);

const ChipRow = clsx(
    "flex flex-wrap items-center justify-center gap-3"
);

const ChipItem = clsx(
    "flex items-center gap-1"
);

const Chip = clsx(
    "inline-flex items-center gap-1 shrink-0",
    "border rounded-full",
    "bg-[#20232C]",
    "px-2 py-0.5",
    "text-[12px]"
);

const ChipCount = clsx(
    "text-[17px] text-[#FFFFFF] font-normal"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);
