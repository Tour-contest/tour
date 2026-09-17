import { useEffect, useState } from "react";
import clsx from "clsx";
import { LoadingIndicator } from "@/components/common";
import { useAdmin } from "@/hooks/api";

type AdminDashboardState = {
    apiCalls: ApiCallsData | null;
    mapping: MappingMetricsData | null;
    isLoading: boolean;
};

const INITIAL_DASHBOARD: AdminDashboardState = {
    apiCalls: null,
    mapping: null,
    isLoading: true,
};

// 상류 오퍼레이션명을 화면용 한글 라벨로 바꾼다. 미등록 값은 원본을 그대로 보여준다
const OPERATION_LABEL: Record<string, string> = {
    tatsCnctrRate: "관광지 집중률 조회",
    searchKeyword2: "키워드 검색",
};

const QUOTA_WARNING_RATE = 0.7;
const QUOTA_DANGER_RATE = 0.9;

const sectionStyle = clsx("flex", "flex-col", "gap-[12px]", "rounded-[12px]", "border-[1px]", "border-[#e5e4e7]", "p-[16px]");
const sectionTitleStyle = clsx("text-[14px]", "font-bold");
const tileLabelStyle = clsx("text-[12px]", "text-[#6b6375]");
const tileValueStyle = clsx("text-[20px]", "font-bold");
const mutedStyle = clsx("text-[12px]", "text-[#6b6375]");

const BannerStyle = {
    danger: clsx("rounded-[8px]", "bg-[#ffe9e7]", "p-[12px]", "text-[13px]", "text-[#c02418]"),
    warning: clsx("rounded-[8px]", "bg-[#fff4e0]", "p-[12px]", "text-[13px]", "text-[#8a5a00]"),
} as const;

const GaugeStyle = {
    danger: "bg-[#ff3b30]",
    warning: "bg-[#e6a117]",
    normal: "bg-[#1a8c4a]",
} as const;

const resolveQuotaLevel = (usedRate: number) => {
    if (usedRate >= QUOTA_DANGER_RATE) return "danger";
    if (usedRate >= QUOTA_WARNING_RATE) return "warning";
    return "normal";
};

const formatTokens = (tokens: number) => {
    if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
    if (tokens >= 1_000) return `${Math.round(tokens / 1_000)}K`;
    return String(tokens);
};

// 당일 사용 추세를 그대로 연장해 소진 시각을 추정한다 (대화 1회당 상류 4~8건 소모)
const predictExhaustionTime = (quota: ApiCallQuota) => {
    if (quota.used_today <= 0 || quota.remaining <= 0) return null;

    const now = new Date();
    const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const elapsedHours = (now.getTime() - midnight.getTime()) / 3_600_000;
    if (elapsedHours <= 0) return null;

    const perHour = quota.used_today / elapsedHours;
    const exhaustedAt = new Date(now.getTime() + (quota.remaining / perHour) * 3_600_000);

    // 오늘 안에 소진되지 않을 추세면 예측을 표시하지 않는다
    if (exhaustedAt.getDate() !== now.getDate()) return null;

    return `${String(exhaustedAt.getHours()).padStart(2, "0")}:${String(exhaustedAt.getMinutes()).padStart(2, "0")}`;
};

function Admin() {
    const { fetchApiCallMetrics, fetchMappingMetrics } = useAdmin();

    const [dashboard, setDashboard] = useState<AdminDashboardState>(INITIAL_DASHBOARD);

    useEffect(() => {
        Promise.all([fetchApiCallMetrics(), fetchMappingMetrics()]).then(([apiCalls, mapping]) => {
            setDashboard({ apiCalls, mapping, isLoading: false });
        });
    }, []);

    if (dashboard.isLoading) {
        return (
            <div className={clsx("flex", "h-full", "items-center", "justify-center")}>
                <LoadingIndicator label="지표를 불러오는 중…" />
            </div>
        );
    }

    if (!dashboard.apiCalls) {
        return (
            <div className={clsx("flex", "h-full", "items-center", "justify-center")}>
                <p className={clsx("text-[13px]", "text-[#ff3b30]")}>지표를 불러오지 못했습니다.</p>
            </div>
        );
    }

    const { quota, by_operation, error_rate, avg_latency_ms, cache_hits, cache_enabled, llm, daily, recent, date } =
        dashboard.apiCalls;

    const usedRate = quota.limit > 0 ? quota.used_today / quota.limit : 0;
    const quotaLevel = resolveQuotaLevel(usedRate);
    const exhaustionTime = predictExhaustionTime(quota);

    const matchedRate = dashboard.mapping && dashboard.mapping.total > 0
        ? (dashboard.mapping.matched / dashboard.mapping.total) * 100
        : null;

    const operations = Object.entries(by_operation).sort((a, b) => b[1] - a[1]);
    const maxDailyCalls = Math.max(...daily.map((day) => day.real + day.cached), 1);

    return (
        <div className={clsx("flex", "h-full", "flex-col", "gap-[16px]", "overflow-y-auto", "p-[24px]", "animate-fade-in", "motion-reduce:animate-none")}>
            {quotaLevel !== "normal" && (
                <p className={BannerStyle[quotaLevel]}>
                    TourAPI 할당량 {Math.round(usedRate * 100)}% 사용
                    {exhaustionTime && ` — 이 추세면 ${exhaustionTime} 소진`}
                </p>
            )}

            <div className={clsx("grid", "grid-cols-4", "gap-[12px]")}>
                <div className={sectionStyle}>
                    <p className={tileLabelStyle}>TourAPI</p>
                    <p className={tileValueStyle}>
                        {quota.used_today.toLocaleString()}/{quota.limit.toLocaleString()}
                    </p>
                    <div className={clsx("h-[8px]", "w-full", "rounded-[4px]", "bg-[#e9e7df]")}>
                        <div
                            style={{ width: `${Math.min(usedRate * 100, 100)}%` }}
                            className={clsx("h-full", "rounded-[4px]", GaugeStyle[quotaLevel])}
                        />
                    </div>
                    <p className={mutedStyle}>잔여 {quota.remaining.toLocaleString()}</p>
                </div>

                <div className={sectionStyle}>
                    <p className={tileLabelStyle}>LLM 호출</p>
                    <p className={tileValueStyle}>
                        {llm.calls} · {formatTokens(llm.prompt + llm.completion)}
                    </p>
                    <p className={mutedStyle}>{llm.since}</p>
                </div>

                <div className={sectionStyle}>
                    <p className={tileLabelStyle}>오류율</p>
                    <p className={tileValueStyle}>{(error_rate * 100).toFixed(1)}%</p>
                    <p className={mutedStyle}>평균 {avg_latency_ms}ms</p>
                </div>

                <div className={sectionStyle}>
                    <p className={tileLabelStyle}>집중률 매칭</p>
                    <p className={tileValueStyle}>
                        {matchedRate === null ? "-" : `성공률 ${matchedRate.toFixed(1)}%`}
                    </p>
                    {dashboard.mapping && (
                        <p className={mutedStyle}>
                            {dashboard.mapping.matched.toLocaleString()} / {dashboard.mapping.total.toLocaleString()}
                        </p>
                    )}
                </div>
            </div>

            <div className={sectionStyle}>
                <p className={sectionTitleStyle}>오퍼레이션별 호출 ({date})</p>
                {operations.length === 0 && <p className={mutedStyle}>호출 기록이 없습니다</p>}
                {operations.map(([operation, count]) => (
                    <div key={operation} className={clsx("flex", "items-center", "justify-between", "text-[13px]")}>
                        <span>{OPERATION_LABEL[operation] ?? operation}</span>
                        <span>{count.toLocaleString()}</span>
                    </div>
                ))}
                <p className={mutedStyle}>
                    중복 제거로 절약 {cache_hits.toLocaleString()}건{!cache_enabled && " (중복 제거 비활성)"}
                </p>
            </div>

            <div className={sectionStyle}>
                <p className={sectionTitleStyle}>일자별 호출 추이</p>
                <div className={clsx("flex", "items-end", "gap-[8px]", "h-[100px]")}>
                    {daily.map((day) => (
                        <div key={day.date} className={clsx("flex", "flex-1", "flex-col", "items-center", "gap-[4px]")}>
                            <div
                                style={{ height: `${((day.real + day.cached) / maxDailyCalls) * 80}px` }}
                                className={clsx("w-full", "rounded-t-[4px]", "bg-[#1a8c4a]")}
                            />
                            <span className={mutedStyle}>{day.date.slice(5)}</span>
                        </div>
                    ))}
                </div>
            </div>

            <div className={sectionStyle}>
                <p className={sectionTitleStyle}>최근 호출 이력</p>
                {recent.map((log) => (
                    <div key={log.id} className={clsx("flex", "items-center", "justify-between", "gap-[12px]", "text-[13px]")}>
                        <span className={clsx("truncate")}>{OPERATION_LABEL[log.operation] ?? log.operation}</span>
                        <span className={mutedStyle}>
                            {log.status_code} · {log.latency_ms}ms
                            {log.cache_hit === 1 && " · 중복제거"}
                        </span>
                    </div>
                ))}
            </div>
        </div>
    );
}
export default Admin;
