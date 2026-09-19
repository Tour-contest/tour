import { formatRate } from "../utils/crowdVisual";

// 스토리보드의 "함께 찾는 곳 N위"는 명세에 순위 값이 없어, 실제로 내려오는 근거로 한 줄을 만든다.
// similarity 는 절대값 분포가 모델마다 달라 순위 판단에만 쓰라고 되어 있어 표시하지 않는다
export const buildReasonText = (reason: AlternativesTouristReason | undefined) => {
    const parts: string[] = [];

    if (reason?.distance_km != null) parts.push(`${formatRate(reason.distance_km)}km`);
    // lower_by 는 점수 차이이며 퍼센트가 아니다 (명세)
    if (reason?.lower_by != null) parts.push(`혼잡도 ${formatRate(reason.lower_by)} 낮음`);
    if (reason?.same_category) parts.push("비슷한 분류");

    return parts.join(" · ");
};

export const buildCandidateSourceText = (candidateSource: AlternativesTouristData["candidate_source"] | undefined, region: string | undefined) => {
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
