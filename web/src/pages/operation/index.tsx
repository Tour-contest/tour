//react
import { useState } from "react";
//hooks
import { useAdmin } from "@/hooks/api";
import useAsyncData from "@/hooks/useAsyncData";
//components
import { LogoLoading, Pagination } from "@/components/common";
import OperationFilters from "./OperationFilters";
import OperationLogTable from "./OperationLogTable";
//features
import { FETCH_LIMIT, PAGE_SIZE, buildRequestParams, sliceLogsPage, type ProviderFilter } from "./utils/operationLog";
//style
import clsx from "clsx";

// 호출 이력 전체 보기 (/operation). 서버에 offset 이 없어 하루치를 최대 500건 받아 화면에서 10개씩 나눈다.
// 날짜 · 제공자를 바꾸면 다시 받고 첫 페이지로 돌아간다
const Operation = () => {
    const { fetchApiCallMetrics } = useAdmin();

    const [day, setDay] = useState<string>("");
    const [provider, setProvider] = useState<ProviderFilter>("all");
    const [page, setPage] = useState<number>(0);

    const { data, isLoading, hasError, reload } = useAsyncData(
        `${day}|${provider}`,
        () => fetchApiCallMetrics(buildRequestParams(day, provider)),
    );

    const handleDayChange = (nextDay: string) => {
        setDay(nextDay);
        setPage(0);
    };

    const handleProviderChange = (nextProvider: ProviderFilter) => {
        setProvider(nextProvider);
        setPage(0);
    };

    const logs = data?.recent ?? [];
    const pageCount = Math.max(1, Math.ceil(logs.length / PAGE_SIZE));
    const visibleLogs = sliceLogsPage(logs, page);
    const isCapped = logs.length >= FETCH_LIMIT;

    return <div className={Page}>
        <div className={Header}>
            <h1 className={Title}>호출 이력</h1>
            {data && <p className={Muted}>{data.date} · {logs.length.toLocaleString()}건</p>}
        </div>

        <section className={Section}>
            <OperationFilters day={day} onDayChange={handleDayChange} provider={provider} onProviderChange={handleProviderChange} />

            {isLoading && (
                <div className={CenterNote}>
                    <LogoLoading label="호출 이력을 불러오는 중…" />
                </div>
            )}

            {hasError && (
                <div className={CenterNote}>
                    <p className={ErrorText}>호출 이력을 불러오지 못했어요.</p>
                    <button type="button" onClick={reload} className={Button}>다시 시도</button>
                </div>
            )}

            {!isLoading && !hasError && logs.length === 0 && (
                <p className={clsx(CenterNote, Muted)}>호출 기록이 없습니다</p>
            )}

            {!isLoading && !hasError && logs.length > 0 && (
                <>
                    <OperationLogTable logs={visibleLogs} />
                    <div className={Footer}>
                        <p className={Muted}>
                            {(page * PAGE_SIZE + 1).toLocaleString()}–{(page * PAGE_SIZE + visibleLogs.length).toLocaleString()} / {logs.length.toLocaleString()}
                            {/* 서버 최대치만큼 받았으면 그 뒤 기록은 못 본다 — 알린다 */}
                            {isCapped && ` (최근 ${FETCH_LIMIT}건까지만 보여요)`}
                        </p>
                        <Pagination page={page} pageCount={pageCount} onChange={setPage} label="호출 이력 페이지" />
                    </div>
                </>
            )}
        </section>
    </div>
}
export default Operation;
//style configuration
// 대시보드와 같은 어두운 톤 · 얇은 호버 스크롤바 (index.css 의 scrollbar-thin-hover)
const Page = clsx(
    "flex h-full flex-col gap-4",
    "overflow-y-auto",
    "bg-[#20232C]",
    "p-6",
    "animate-fade-in motion-reduce:animate-none",
    "scrollbar-thin-hover",
);

const Header = clsx(
    "flex items-baseline gap-3"
);

const Title = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const Section = clsx(
    "flex flex-col gap-4",
    "bg-[#333743]",
    "rounded-[12px]",
    "p-[22px_32px] box-border"
);

const CenterNote = clsx(
    "flex flex-col items-center justify-center gap-2",
    "py-10"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);

const ErrorText = clsx(
    "text-[13px] text-[#FF7A7A]"
);

const Button = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1",
    "text-[12px] text-[#FFFFFF]",
    "cursor-pointer",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]"
);

const Footer = clsx(
    "flex items-center justify-between gap-3"
);
