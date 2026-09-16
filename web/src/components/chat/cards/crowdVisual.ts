// 등급은 좋음·주의·위험 의미를 가진 상태값이라 검증된 상태 팔레트를 쓴다 (한적 good · 보통 warning · 혼잡 critical).
// 색만으로 뜻을 전하지 않도록 항상 등급 글자와 함께 쓰고, 글자 자체에는 데이터 색을 칠하지 않는다
// (보통의 노란색은 흰 배경에서 대비가 낮아 글자로 쓰면 읽히지 않는다)
export const LevelFill = {
    한적: "bg-[#0ca30c]",
    보통: "bg-[#fab219]",
    혼잡: "bg-[#d03b3b]",
} as const;

export const LevelDotBase = "size-2 shrink-0 rounded-full";

const toDateKey = (date: Date) => {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
};

export const isToday = (date: string | undefined) => date === toDateKey(new Date());

// 요청한 기준일로 집계되므로 "오늘"로 고정하면 미래 날짜 조회가 오늘 자료처럼 보인다
export const formatDateLabel = (date: string | undefined) => {
    if (!date || isToday(date)) return "오늘";

    const [, month, day] = date.split("-");
    return `${Number(month)}월 ${Number(day)}일`;
};

export const formatShortDate = (date: string) => {
    const [, month, day] = date.split("-");
    return `${Number(month)}/${Number(day)}`;
};

// 집중률은 비율이 아닌 지수라 % 를 붙이지 않는다 (명세). 긴 소수만 둘째 자리로 정리한다
export const formatRate = (value: number) => String(Math.round(value * 100) / 100);

// 좌표가 없는 응답도 있어 이름으로 검색해 연다. API 키 없이 쓰는 카카오맵 검색 링크
export const buildKakaoMapSearchUrl = (keyword: string) => {
    return `https://map.kakao.com/link/search/${encodeURIComponent(keyword)}`;
};
