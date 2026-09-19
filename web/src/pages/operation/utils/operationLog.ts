// 호출 이력 페이지의 화면 규칙 (UI 아님)

// 한 페이지 개수 — 전체 대화 팝업과 같은 규칙
export const PAGE_SIZE = 10;
// 서버가 한 번에 주는 최대치 (limit 1~500). offset 이 없어 이만큼 받아 화면에서 나눈다
export const FETCH_LIMIT = 500;

// 로그에 저장된 provider 값 기준 (data.go.kr · naver). 문서에 적힌 tourapi 는 서버가 못 알아듣는다
export const PROVIDER_LABEL: Record<ApiCallProvider, string> = {
    "data.go.kr": "TourAPI",
    naver: "네이버",
};

export type ProviderFilter = "all" | ApiCallProvider;

export const PROVIDER_OPTIONS: ApiCallProvider[] = ["data.go.kr", "naver"];

// 필터를 요청 파라미터로. "" 날짜는 서버 기본(오늘) 이라 보내지 않는다
export const buildRequestParams = (day: string, provider: ProviderFilter): RequestApiCallsParams => ({
    limit: FETCH_LIMIT,
    ...(day ? { day } : {}),
    ...(provider !== "all" ? { provider } : {}),
});

// 오늘(KST) YYYY-MM-DD — date 입력의 max 로 쓴다
export const todayKst = (): string => {
    const kst = new Date(Date.now() + 9 * 60 * 60 * 1000);
    return kst.toISOString().slice(0, 10);
};

// "14:02:35". 날짜는 필터에 있으니 시각만. 원문은 title 툴팁에
export const formatCallTime = (iso: string): string => {
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return iso;
    return [date.getHours(), date.getMinutes(), date.getSeconds()].map((n) => String(n).padStart(2, "0")).join(":");
};

export type StatusTone = "ok" | "error";

// 2xx 만 정상. status 가 없으면(네트워크 실패 등) 오류로 본다
export const resolveStatusTone = (log: ApiCallLog): StatusTone => {
    if (log.status_code === null) return "error";
    return log.status_code >= 200 && log.status_code < 300 ? "ok" : "error";
};

export const sliceLogsPage = (logs: ApiCallLog[], page: number): ApiCallLog[] =>
    logs.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);
