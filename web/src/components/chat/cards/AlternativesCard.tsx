import clsx from "clsx";
import LevelChip from "./LevelChip";
import { buildKakaoMapSearchUrl, formatRate } from "./crowdVisual";

type AlternativesCardNeedProps = {
    payload: AlternativesTouristData;
};

// 명세: 화면은 상위 3개만 그린다
const VISIBLE_COUNT = 3;

// 스토리보드의 "함께 찾는 곳 N위"는 명세에 순위 값이 없어, 실제로 내려오는 근거로 한 줄을 만든다.
// similarity 는 절대값 분포가 모델마다 달라 순위 판단에만 쓰라고 되어 있어 표시하지 않는다
const buildReasonText = (reason: AlternativesTouristReason | undefined) => {
    const parts: string[] = [];

    if (reason?.distance_km != null) parts.push(`${formatRate(reason.distance_km)}km`);
    // lower_by 는 점수 차이이며 퍼센트가 아니다 (명세)
    if (reason?.lower_by != null) parts.push(`혼잡도 ${formatRate(reason.lower_by)} 낮음`);
    if (reason?.same_category) parts.push("비슷한 분류");

    return parts.join(" · ");
};

const buildCandidateSourceText = (candidateSource: AlternativesTouristData["candidate_source"] | undefined, region: string | undefined) => {
    const regionText = region ? `${region} 전체` : "지역 전체";

    switch (candidateSource) {
        case "related":
            return "함께 찾는 관광지 중에서 골랐어요";
        case "area":
            return `${regionText}에서 골랐어요`;
        case "related+area":
            return `함께 찾는 관광지와 ${regionText}에서 골랐어요`;
        default:
            return null;
    }
};

// SB-03 STEP 3 — 덜 붐비는 대안 추천
const AlternativesCard = ({ payload } : AlternativesCardNeedProps) => {
    // 순서는 서버가 확정한 값이라 재정렬하지 않는다 (명세)
    const items = payload.items.slice(0, VISIBLE_COUNT);
    const region = payload.signgu_nm;
    const baseName = payload.base?.name;
    const candidateSourceText = buildCandidateSourceText(payload.candidate_source, region);

    return <div className={CardShell}>
        <div className={CardHeader}>
            <p className={CardTitle}>{baseName ? `${baseName} 대신 여기는 어때요?` : "덜 붐비는 곳을 찾았어요"}</p>
            {payload.base?.level && payload.base.rate != null && (
                <LevelChip level={payload.base.level} rate={payload.base.rate} prefix="지금" />
            )}
        </div>

        <ul className={ItemList}>
            {
                items.map((item) => {
                    const reasonText = buildReasonText(item.reason);
                    const mapKeyword = region ? `${region} ${item.name}` : item.name;

                    return <li key={item.content_id ?? item.name} className={ItemRow}>
                        <div className={ItemMain}>
                            <div className={ItemTitleRow}>
                                <p className={ItemName}>{item.name}</p>
                                <LevelChip level={item.level} rate={item.rate} />
                            </div>
                            {reasonText && <p className={Muted}>{reasonText}</p>}
                        </div>
                        <a
                            href={buildKakaoMapSearchUrl(mapKeyword)}
                            target="_blank"
                            rel="noopener noreferrer"
                            aria-label={`${item.name} 카카오맵에서 보기 (새 창)`}
                            className={MapLink}
                        >
                            지도 ↗
                        </a>
                    </li>
                })
            }
        </ul>

        {/* 명세: relaxed=true 이면 조건을 완화한 결과임을 표시한다 */}
        {payload.relaxed && (
            <p className={Notice}>더 한적한 곳을 찾지 못해 혼잡도가 낮은 순으로 보여드려요</p>
        )}

        <div className={FooterNotes}>
            <p className={Muted}>
                {candidateSourceText ? `${candidateSourceText} · ` : ""}집중률은 예측값이에요
            </p>
            {payload.source && <p className={Muted}>{payload.source}</p>}
        </div>
    </div>
}
export default AlternativesCard;
//style configuration
const CardShell = clsx(
    "flex flex-col gap-3",
    "border border-[#e5e4e7] rounded-[12px]",
    "bg-white",
    "p-4 box-border",
    "text-[13px]"
);

const CardHeader = clsx(
    "flex items-start justify-between gap-3"
);

const CardTitle = clsx(
    "text-[15px] font-bold"
);

const ItemList = clsx(
    "flex flex-col",
    "border-t border-[#e1e0d9]"
);

const ItemRow = clsx(
    "flex items-center justify-between gap-3",
    "border-b border-[#e1e0d9] last:border-b-0",
    "py-2.5"
);

const ItemMain = clsx(
    "flex flex-col gap-1 min-w-0"
);

const ItemTitleRow = clsx(
    "flex flex-wrap items-center gap-2"
);

const ItemName = clsx(
    "text-[14px] font-semibold"
);

const Muted = clsx(
    "text-[12px] text-[#6b6375]"
);

const MapLink = clsx(
    "shrink-0",
    "border border-[#b1bdc8] rounded-[8px]",
    "px-2.5 py-1",
    "text-[12px]",
    "hover:bg-[#f4f3ec]"
);

const Notice = clsx(
    "rounded-[8px]",
    "bg-[#f4f3ec]",
    "px-3 py-2",
    "text-[12px]"
);

const FooterNotes = clsx(
    "flex flex-col gap-0.5"
);
