//features
import { resolveOperationLabel } from "@/pages/admin/utils/dashboard";
import { PROVIDER_LABEL, formatCallTime, resolveStatusTone } from "./utils/operationLog";
//style
import clsx from "clsx";

type OperationLogTableNeedProps = {
    logs: ApiCallLog[];
};

// 호출 이력 한 페이지 분량의 표. 시각 · 오퍼레이션 · 제공자 · 상태 · 지연 · 세션
const OperationLogTable = ({ logs } : OperationLogTableNeedProps) => {
    return <table className={DataTable}>
        <thead>
            <tr className={TableHeadRow}>
                <th scope="col" className={clsx(TableCell, "w-[96px]")}>시각</th>
                <th scope="col" className={TableCell}>오퍼레이션</th>
                <th scope="col" className={clsx(TableCell, "w-[96px]")}>제공자</th>
                <th scope="col" className={clsx(TableCell, "w-[160px]")}>상태</th>
                <th scope="col" className={clsx(TableCell, NumberCell, "w-[96px]")}>지연</th>
                <th scope="col" className={clsx(TableCell, "w-[160px]")}>세션</th>
            </tr>
        </thead>
        <tbody>
            {
                logs.map((log) => {
                    const tone = resolveStatusTone(log);
                    return <tr key={log.id} className={TableRow}>
                        <td className={clsx(TableCell, "tabular-nums")} title={log.called_at}>{formatCallTime(log.called_at)}</td>
                        <th scope="row" className={TableCell} title={log.params ?? undefined}>
                            <span className={KeyLabel}>{resolveOperationLabel(log.operation)}</span>
                            <span className={KeyCode}>{log.operation}</span>
                        </th>
                        <td className={TableCell}>{PROVIDER_LABEL[log.provider] ?? log.provider}</td>
                        <td className={clsx(TableCell, "tabular-nums")}>
                            <span className={tone === "ok" ? StatusOk : StatusError}>{log.status_code ?? "실패"}</span>
                            {log.cache_hit === 1 && <span className={CacheBadge}>중복제거</span>}
                            {log.result_code && <span className={KeyCode}>결과 {log.result_code}</span>}
                        </td>
                        <td className={clsx(TableCell, NumberCell)}>{log.latency_ms === null ? "-" : `${log.latency_ms.toLocaleString()}ms`}</td>
                        <td className={TableCell} title={log.session_id ?? undefined}>
                            <span className={SessionId}>{log.session_id ?? "-"}</span>
                        </td>
                    </tr>
                })
            }
        </tbody>
    </table>
}
export default OperationLogTable;
//style configuration
// 대시보드 오퍼레이션별 호출 표와 같은 규칙
const DataTable = clsx(
    "w-full border-collapse table-fixed",
    "text-[14px] text-[#D8D8D8]"
);

const TableHeadRow = clsx(
    "border-b border-[#63717A]",
    "text-[12px] text-[#909090]"
);

const TableRow = clsx(
    "border-b border-[#3A3D47]",
    "hover:bg-[#3A3D47]"
);

const TableCell = clsx(
    "py-2.5 px-2 text-left font-normal align-middle"
);

const NumberCell = clsx(
    "text-right tabular-nums"
);

const KeyLabel = clsx(
    "block truncate text-[#FFFFFF]"
);

const KeyCode = clsx(
    "block truncate text-[12px] text-[#909090] font-normal"
);

const StatusOk = clsx(
    "text-[#4CD96A]"
);

const StatusError = clsx(
    "text-[#FF8A5C]"
);

const CacheBadge = clsx(
    "ml-1.5 inline-flex items-center",
    "rounded-full px-2 py-0.5",
    "bg-[#20232C] text-[11px] text-[#A3F1F9]"
);

const SessionId = clsx(
    "block truncate text-[12px] text-[#909090] tabular-nums"
);
