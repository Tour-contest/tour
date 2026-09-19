const SIDO_SUFFIX = /(특별자치시|특별자치도|특별시|광역시|도)$/;
const SIGNGU_SUFFIX = /(시|군|구)$/;
// "충청북도 → 충북"처럼 두 글자로 줄여 부르는 도 이름
const TWO_WORD_PROVINCE = /^..[남북]도$/;
// "서울에서", "광주의"처럼 지역명에 붙여 쓴 조사
const PARTICLES = ["에서는", "에서", "으로", "에는", "에선", "에", "의", "은", "는", "이", "가", "을", "를", "로", "도"];

// 한 글자 약칭("중구 → 중")은 일반 단어와 겹치므로 두 글자 이상만 지역명으로 본다
const addRegionName = (names: Set<string>, name: string) => {
    if (name.length >= 2) names.add(name);
};

const buildRegionNames = (sidoGroups: SidoGroup[]) => {
    const names = new Set<string>();

    for (const group of sidoGroups) {
        addRegionName(names, group.sido_nm);
        addRegionName(names, group.sido_nm.replace(SIDO_SUFFIX, ""));
        if (TWO_WORD_PROVINCE.test(group.sido_nm)) addRegionName(names, group.sido_nm[0] + group.sido_nm[2]);

        for (const area of group.items) {
            // "수원시 장안구"처럼 띄어 쓴 시군구명도 단어별로 등록한다
            for (const word of area.signgu_nm.split(" ")) {
                addRegionName(names, word);
                addRegionName(names, word.replace(SIGNGU_SUFFIX, ""));
            }
        }
    }
    return names;
};

// 단어 전체가 지역명이거나 "지역명 + 조사"일 때만 지역으로 본다.
// "대구탕", "세종대왕릉"처럼 지역명으로 시작하는 다른 단어는 건드리지 않기 위해 부분 일치는 쓰지 않는다
const isRegionWord = (word: string, regionNames: Set<string>) => {
    if (regionNames.has(word)) return true;

    return PARTICLES.some((particle) => {
        return word.endsWith(particle) && regionNames.has(word.slice(0, -particle.length));
    });
};

// 질문에 이미 들어 있던 지역을 빼고 새 지역으로 교체한다. 그대로 앞에 붙이면
// "전라남도 순천시 서울특별시 전체 혼잡 현황"처럼 지역이 충돌하고, 다시 묻기를 반복할수록 쌓인다
export const replaceQuestionRegion = (question: string, region: string, sidoGroups: SidoGroup[]) => {
    const regionNames = buildRegionNames(sidoGroups);

    const baseQuestion = question
        .split(/\s+/)
        .filter((word) => word && !isRegionWord(word, regionNames))
        .join(" ");

    return baseQuestion ? `${region} ${baseQuestion}` : `${region} 알려줘`;
};
