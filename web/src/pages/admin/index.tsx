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

// 대화 카드와 같은 어두운 톤 (배경 #20232C · 카드 #333743 · 흰 제목 · 보조 #909090)
const sectionStyle = clsx("flex", "flex-col", "gap-3", "rounded-[12px]", "bg-[#333743]", "p-[22px_32px]", "box-border", "text-[#FFFFFF] flex-1");
const sectionTitleStyle = clsx("text-[20px]", "text-[#FFFFFF]", "font-medium");
const mutedStyle = clsx("text-[12px]", "text-[#909090]");
const sectionHeaderStyle = clsx("flex", "items-baseline", "justify-between", "gap-3");
const moreLinkStyle = clsx("text-[13px]", "text-[#6FC1FC]", "hover:text-[#A3F1F9]", "hover:underline");
const rowStyle = clsx("flex", "items-center", "justify-between", "gap-3", "text-[14px]", "text-[#D8D8D8]");


// 챗봇 · 상세와 같은 얇은 스크롤바
const pageStyle = clsx(
    "flex h-full flex-col gap-4",
    "overflow-y-auto",
    "bg-[#20232C]",
    "p-6",
    "animate-fade-in motion-reduce:animate-none",
    "[scrollbar-width:thin] [scrollbar-color:transparent_transparent]",
    "hover:[scrollbar-color:#3A3D47_transparent]",
    "[&::-webkit-scrollbar]:w-1.5",
    "[&::-webkit-scrollbar-track]:bg-transparent",
    "[&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-transparent",
    "hover:[&::-webkit-scrollbar-thumb]:bg-[#3A3D47]",
);

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
                <p className={clsx("text-[13px]", "text-[#FF6B6B]")}>지표를 불러오지 못했습니다.</p>
                <button type="button" onClick={reload} className={clsx("text-[12px]", "text-[#D8D8D8]", "underline", "cursor-pointer")}>다시 시도</button>
            </div>
        );
    }

    const { daily, recent } = dashboard.apiCalls;

    console.log(dashboard.apiCalls);


    return (
        <div className={pageStyle}>
            <TourApiMonitor dashboard={dashboard} />
            <div className="flex gap-4 h-[360px] shrink-0">
                <CaseByOperationCall dashboard={dashboard} />
                <div className={sectionStyle}>
                    <p className={sectionTitleStyle}>일자별 호출 추이</p>
                    <DailyCallsChart daily={daily} />
                </div>
            </div>
            <div className={sectionStyle}>
                <div className={sectionHeaderStyle}>
                    <p className={sectionTitleStyle}>최근 호출 이력</p>
                    <Link to="/operation" className={moreLinkStyle}>전체 보기</Link>
                </div>
                {recent.length === 0 && <p className={mutedStyle}>호출 기록이 없습니다</p>}
                {recent.map((log) => (
                    <div key={log.id} className={rowStyle}>
                        <span className={clsx("truncate")}>{resolveOperationLabel(log.operation)}</span>
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
