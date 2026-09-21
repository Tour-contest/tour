import clsx from "clsx";
import { Link } from "react-router";
import { LogoLoading } from "@/components/common";
import { useAdmin } from "@/hooks/api";
import useAsyncData from "@/hooks/useAsyncData";
import DailyCallsChart from "./DailyCallsChart";
import TourApiMonitor from "./TourApiMonitor";
import CaseByOperationCall from "./CaseByOperationCall";
import { resolveOperationLabel } from "./utils/dashboard";

// 대시보드에는 최근 호출을 이만큼만. 전체는 /operation 에서 (서버 limit 1~500)
const RECENT_LIMIT = 5;

export type AdminDashboardData = {
    apiCalls: ApiCallsData | null;
    mapping: MappingMetricsData | null;
};

function Admin() {
    const { fetchApiCallMetrics, fetchMappingMetrics } = useAdmin();

    // 지표 두 종을 한 번에 받는다. 호출 지표가 없으면 화면을 못 그리므로 그때만 실패로 본다
    const { data: dashboard, isLoading, hasError, reload } = useAsyncData<AdminDashboardData>("dashboard", async () => {
        const [apiCalls, mapping] = await Promise.all([fetchApiCallMetrics({ limit: RECENT_LIMIT }), fetchMappingMetrics()]);
        return apiCalls ? { apiCalls, mapping } : null;
    });

    if (isLoading) {
        return (
            <div className={clsx("flex", "h-full", "items-center", "justify-center", "bg-[#20232C]")}>
                <LogoLoading label="지표를 불러오는 중…" />
            </div>
        );
    }

    if (hasError || !dashboard?.apiCalls) {
        return (
            <div className={clsx("flex", "h-full", "flex-col", "items-center", "justify-center", "gap-2", "bg-[#20232C]")}>
                <p className={clsx("text-[13px]", "text-[#FF7A7A]")}>지표를 불러오지 못했습니다.</p>
                <button type="button" onClick={reload} className={clsx("text-[12px]", "text-[#D8D8D8]", "underline", "cursor-pointer")}>다시 시도</button>
            </div>
        );
    }

    const { daily, recent } = dashboard.apiCalls;

    return (
        <div className={PageStyle}>
            {/* 화면엔 메뉴가 제목 역할을 하지만 보조기기용 페이지 제목은 둔다 */}
            <div className={ContentColumn}>
                <h1 className="sr-only">관제 대시보드</h1>
                <TourApiMonitor dashboard={dashboard} />
                <div className={ChartRow}>
                    <CaseByOperationCall dashboard={dashboard} />
                    <div className={clsx(SectionStyle, "flex-1")}>
                        <h2 className={SectionTitleStyle}>일자별 호출 추이</h2>
                        <DailyCallsChart daily={daily} />
                    </div>
                </div>
                {/* h-full 은 위 카드들 높이만큼 밖으로 밀려난다 — 남은 높이만 가져가도록 flex-1 */}
                <div className={clsx(SectionStyle, "flex-1")}>
                    <div className={SectionHeaderStyle}>
                        <h2 className={SectionTitleStyle}>최근 호출 이력</h2>
                        <Link to="/operation" className={MoreLinkStyle}>전체 보기</Link>
                    </div>
                    {recent.length === 0 && <p className={MutedStyle}>호출 기록이 없습니다</p>}
                    {recent.map((log) => (
                        <div key={log.id} className={RowStyle}>
                            <span className={clsx("truncate")}>{resolveOperationLabel(log.operation)}</span>
                            <span className={MutedStyle}>
                                {log.status_code} · {log.latency_ms}ms
                                {log.cache_hit === 1 && " · 중복제거"}
                            </span>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
}
export default Admin;
//style configuration
const ContentColumn = clsx(
    "w-full max-w-380",
    "flex flex-col gap-4",
    "grow shrink-0"
);

const ChartRow = clsx(
    "flex flex-col gap-4 shrink-0",
    "@7xl:flex-row @7xl:h-[360px]"
);

const SectionStyle = clsx(
    "bg-[#333743]",
    "flex flex-col gap-3 min-w-0",
    "rounded-[12px]",
    "p-[22px_32px] box-border",
    "text-[#FFFFFF]");

const SectionTitleStyle = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);
const MutedStyle = clsx(
    "text-[12px] text-[#909090] font-normal"
);

const SectionHeaderStyle = clsx(
    "flex items-center justify-between gap-3"
);

const MoreLinkStyle = clsx(
    "text-[13px] text-[#309AE6] hover:text-[#6FC1FC] hover:underline",
);
const RowStyle = clsx(
    "flex items-center justify-between gap-3", 
    "text-[14px] text-[#D8D8D8] font-normal"
);

// 얇은 호버 스크롤바 (index.css 의 scrollbar-thin-hover)
const PageStyle = clsx(
    "@container",
    "flex h-full flex-col items-center",
    "overflow-y-auto",
    "bg-[#20232C]",
    "p-[24px_40px] box-border",
    "animate-fade-in motion-reduce:animate-none",
    "scrollbar-thin-hover",
);