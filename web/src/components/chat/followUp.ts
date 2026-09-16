export type FollowUp = {
    label: string;
    message: string;
};

// 지역 전체 혼잡도인지 판별한다. no_data 응답엔 summary 가 없을 수 있어(명세 Nullable) summary 만 보면
// 관광지 혼잡도로 잘못 분류되고, 없는 items 를 읽다가 렌더링 전체가 깨진다 — 필수 필드인 date 로도 판별한다
export const isAreaOverviewPayload = (
    payload: ChatCrowdAttractionPayload | AreaOverviewData,
): payload is AreaOverviewData => "date" in payload || "summary" in payload;

const regionOverviewFollowUp = (region: string): FollowUp => ({
    label: `${region} 전체 현황`,
    message: `${region} 전체 혼잡 현황 알려줘`,
});

// 지역 자체에 집중률 자료가 없으면 전체 현황을 다시 물어도 같은 결과라 관광지 목록으로 유도한다
const regionPlacesFollowUp = (region: string): FollowUp => ({
    label: `${region} 가볼 만한 곳`,
    message: `${region} 가볼 만한 관광지 알려줘`,
});

// 조사(와/과)가 받침에 따라 달라지므로 장소명 뒤에 조사가 붙지 않는 문장으로 만든다
const alternativesFollowUp = (place: string): FollowUp => ({
    label: "함께 찾는 곳 혼잡도",
    message: `${place} 대신 갈 만한 덜 붐비는 곳 알려줘`,
});

const withRegion = (region: string | null | undefined, toFollowUp: (region: string) => FollowUp) => {
    return region ? [toFollowUp(region)] : [];
};

// 명세: "no_data 이거나 has_data 가 false 이면 카드 대신 후속 질문 버튼을 표시한다" (SB-04).
// null 이면 데이터가 있어 카드를 그리고, 배열이면(비어 있을 수 있음) 카드 대신 이 버튼들을 쓴다.
// 네트워크에서 온 값이라 데이터가 없을 때는 필드가 빠져 있을 수 있어 옵셔널 체이닝으로 읽는다
export const resolveFollowUps = (card: ChatCard): FollowUp[] | null => {
    switch (card.type) {
        case "crowd": {
            if (isAreaOverviewPayload(card.payload)) {
                return card.payload.status === "ok" ? null : withRegion(card.payload.signgu_nm, regionPlacesFollowUp);
            }

            const hasSeries = card.payload.items?.some((item) => item.series?.length > 0) ?? false;
            if (card.payload.status === "ok" && hasSeries) return null;

            // 이름 매칭 실패(SB-04)는 unmatched 에 관광지명이 남는다
            const place = card.payload.items?.[0]?.name ?? card.payload.unmatched?.[0];
            return [
                ...withRegion(card.payload.signgu_nm, regionOverviewFollowUp),
                ...(place ? [alternativesFollowUp(place)] : []),
            ];
        }

        case "area_overview":
            return card.payload.status === "ok" ? null : withRegion(card.payload.signgu_nm, regionPlacesFollowUp);

        case "alternatives":
        case "attraction_list":
        case "visitors":
            return card.payload.status === "ok" && (card.payload.items?.length ?? 0) > 0
                ? null
                : withRegion(card.payload.signgu_nm, regionOverviewFollowUp);

        // 관심도는 카드가 아닌 1행 안내이고 no_data 가 흔하다 — 버튼 없이 숨긴다
        case "interest":
            return card.payload.status === "ok" && (card.payload.items?.length ?? 0) > 0 ? null : [];

        default:
            return null;
    }
};
