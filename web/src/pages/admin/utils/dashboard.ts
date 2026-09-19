// 관제 대시보드의 표시 규칙과 계산 (순수 함수 · 상수)

// 상류 오퍼레이션명을 화면용 한글 라벨로 바꾼다. 미등록 값은 원본을 그대로 보여준다.
// 실제 값은 "KorService2/detailCommon2" · "TatsCnctrRateService/tatsCnctrRatedList" 처럼 서비스/오퍼레이션 꼴이라 마지막 조각으로 찾는다
export const OPERATION_LABEL: Record<string, string> = {
    tatsCnctrRatedList: "관광지 집중률 조회",
    tatsCnctrRate: "관광지 집중률 조회",
    searchKeyword2: "키워드 검색",
    areaBasedList2: "지역 기반 관광지 목록",
    locationBasedList2: "위치 기반 관광지 목록",
    detailCommon2: "관광지 상세",
    detailIntro2: "관광지 소개 정보",
    detailImage2: "관광지 이미지",
    detailPetTour2: "반려동물 동반 정보",
    searchFestival2: "축제 검색",
};

export const resolveOperationLabel = (operation: string): string => {
    const name = operation.split("/").pop() ?? operation;
    return OPERATION_LABEL[name] ?? operation;
};

const QUOTA_WARNING_RATE = 0.7;
const QUOTA_DANGER_RATE = 0.9;

export type QuotaLevel = "danger" | "warning" | "normal";

export const resolveQuotaLevel = (usedRate: number): QuotaLevel => {
    if (usedRate >= QUOTA_DANGER_RATE) return "danger";
    if (usedRate >= QUOTA_WARNING_RATE) return "warning";
    return "normal";
};

export const formatTokens = (tokens: number) => {
    if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
    if (tokens >= 1_000) return `${Math.round(tokens / 1_000)}K`;
    return String(tokens);
};

// 당일 사용 추세를 그대로 연장해 소진 시각을 추정한다 (대화 1회당 상류 4~8건 소모)
export const predictExhaustionTime = (quota: ApiCallQuota, now = new Date()) => {
    if (quota.used_today <= 0 || quota.remaining <= 0) return null;

    const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const elapsedHours = (now.getTime() - midnight.getTime()) / 3_600_000;
    if (elapsedHours <= 0) return null;

    const perHour = quota.used_today / elapsedHours;
    const exhaustedAt = new Date(now.getTime() + (quota.remaining / perHour) * 3_600_000);

    // 오늘 안에 소진되지 않을 추세면 예측을 표시하지 않는다
    if (exhaustedAt.getDate() !== now.getDate()) return null;

    return `${String(exhaustedAt.getHours()).padStart(2, "0")}:${String(exhaustedAt.getMinutes()).padStart(2, "0")}`;
};
