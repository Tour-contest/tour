// 지역 방문자 추세의 화면용 계산. 일 단위 응답을 주 단위 막대로 묶는다 (명세: 주별 막대 · data_through 함께 표기)

export type VisitorWeek = {
    // 그 주 월요일 (YYYY-MM-DD). 막대 key 이자 축 라벨의 기준
    weekStart: string;
    // 실제 포함된 날짜 수. 첫 주·마지막 주는 7일이 안 될 수 있다
    days: number;
    total: number;
    // 상류가 구분을 내려준 날만 있으므로, 그 주의 모든 날에 값이 있을 때만 채운다
    local: number | null;
    outsider: number | null;
    foreigner: number | null;
};

export const VISITOR_SEGMENTS = ["local", "outsider", "foreigner"] as const;
export type VisitorSegment = (typeof VISITOR_SEGMENTS)[number];

export const SEGMENT_LABEL: Record<VisitorSegment, string> = {
    local: "현지인",
    outsider: "외지인",
    foreigner: "외국인",
};

// 상태값이 아니라 분류라서 혼잡도 팔레트(초록·노랑·빨강)와 겹치지 않는 색을 쓴다
export const SEGMENT_COLOR: Record<VisitorSegment, string> = {
    local: "#2f6fed",
    outsider: "#8b5cf6",
    foreigner: "#9ca3af",
};

// 구분이 없을 때 합계 하나로 그리는 막대 색
export const TOTAL_COLOR = "#52514e";

const parseDate = (date: string) => {
    const [year, month, day] = date.split("-").map(Number);
    return new Date(year, month - 1, day);
};

const toDateKey = (date: Date) => {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
};

// 월요일 시작. 한국 달력 관행이고, 주말 방문이 한 주 안에 묶인다
const toWeekStart = (date: string) => {
    const parsed = parseDate(date);
    const offset = (parsed.getDay() + 6) % 7;
    parsed.setDate(parsed.getDate() - offset);
    return toDateKey(parsed);
};

const sumOrNull = (values: (number | undefined)[]): number | null => {
    if (values.length === 0 || values.some((value) => typeof value !== "number")) return null;
    return values.reduce<number>((sum, value) => sum + (value ?? 0), 0);
};

// 날짜 오름차순 응답을 주 단위로 합친다. 빠진 날짜(partial)는 그냥 빠진 채로 합산된다
export const groupByWeek = (items: AreaVisitorItem[]): VisitorWeek[] => {
    const buckets = new Map<string, AreaVisitorItem[]>();

    for (const item of items) {
        const weekStart = toWeekStart(item.date);
        const bucket = buckets.get(weekStart);
        if (bucket) bucket.push(item);
        else buckets.set(weekStart, [item]);
    }

    return [...buckets.entries()]
        .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
        .map(([weekStart, days]) => ({
            weekStart,
            days: days.length,
            total: days.reduce((sum, day) => sum + day.total, 0),
            local: sumOrNull(days.map((day) => day.local)),
            outsider: sumOrNull(days.map((day) => day.outsider)),
            foreigner: sumOrNull(days.map((day) => day.foreigner)),
        }));
};

// 현지인·외지인 구분을 쌓아 그릴 수 있는지 — 모든 주에 두 값이 다 있어야 한다 (외국인은 있으면 얹는다)
export const hasBreakdown = (weeks: VisitorWeek[]) => {
    return weeks.length > 0 && weeks.every((week) => week.local !== null && week.outsider !== null);
};

const compactFormatter = new Intl.NumberFormat("ko", { notation: "compact", maximumFractionDigits: 1 });
const fullFormatter = new Intl.NumberFormat("ko-KR");

// 막대 라벨용 짧은 표기 (41,233 → 4.1만). 표에서는 전체 숫자를 쓴다
export const formatCompactCount = (value: number) => compactFormatter.format(value);
export const formatCount = (value: number) => `${fullFormatter.format(value)}명`;

// "6/16 주" 처럼 그 주의 시작일로 부른다
export const formatWeekLabel = (weekStart: string) => {
    const [, month, day] = weekStart.split("-");
    return `${Number(month)}/${Number(day)}`;
};

// 약 75일 지연된 값이라 "최근·요즘" 대신 자료 마지막 날짜를 그대로 보인다
export const formatDataThrough = (date: string) => {
    const [year, month, day] = date.split("-");
    return `${year}년 ${Number(month)}월 ${Number(day)}일 자료까지`;
};
