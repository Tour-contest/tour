//features
import type { AdminDashboardData } from "./index"
import { resolveOperationLabel } from "./utils/dashboard";
//style
import clsx from "clsx";
//icons
import MainLogoIcon from '@/assets/icons/main_logo_icon.svg?react';

type CaseByOperationCallNeedProps = {
    dashboard: AdminDashboardData;
};

// 오퍼레이션별 호출 수를 key(오퍼레이션) / value(호출 수) 표로 보여준다. 많이 부른 순으로 정렬
const CaseByOperationCall = ({ dashboard } : CaseByOperationCallNeedProps) => {
    const { date, by_operation, cache_hits, cache_enabled } = dashboard.apiCalls as ApiCallsData;
    const operations = Object.entries(by_operation).sort((a, b) => b[1] - a[1]);
    const totalCalls = operations.reduce((sum, [, count]) => sum + count, 0);

    return <section className={InterfaceLayout}>
        <h4 className={Title}>오퍼레이션별 호출 ({date})</h4>
        {
            operations.length === 0 ? <div className={EmptyState}>
                <MainLogoIcon className="w-10 h-10 fill-[#909090]" />
                <p className={EmptyText}>호출 기록이 없습니다</p>
            </div> : <div className={TableScroller}>
                <table className={DataTable}>
                    <thead>
                        <tr className={TableHeadRow}>
                            <th scope="col" className={clsx(TableCell, KeyCell)}>오퍼레이션</th>
                            <th scope="col" className={clsx(TableCell, ValueCell)}>호출 수</th>
                        </tr>
                    </thead>
                    <tbody>
                        {
                            operations.map(([operation, count]) => {
                                return <tr key={operation} className={TableRow}>
                                    <th scope="row" className={clsx(TableCell, KeyCell)}>
                                        <span className={KeyLabel}>{resolveOperationLabel(operation)}</span>
                                        <span className={KeyCode}>{operation}</span>
                                    </th>
                                    <td className={clsx(TableCell, ValueCell)}>{count.toLocaleString()}</td>
                                </tr>
                            })
                        }
                    </tbody>
                    <tfoot>
                        <tr className={TableFootRow}>
                            <th scope="row" className={clsx(TableCell, KeyCell)}>합계</th>
                            <td className={clsx(TableCell, ValueCell)}>{totalCalls.toLocaleString()}</td>
                        </tr>
                    </tfoot>
                </table>
                <p className={FooterNote}>
                    중복 제거로 절약 {cache_hits.toLocaleString()}건{!cache_enabled && " (중복 제거 비활성)"}
                </p>
            </div>
        }
    </section>
}
export default CaseByOperationCall;
//style configuraion
const InterfaceLayout = clsx(
    "w-[600px] bg-[#333743]",
    "flex flex-col gap-5",
    "rounded-[10px]",
    "p-[22px_32px] box-border"
);

const Title = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const EmptyState = clsx(
    "flex flex-col gap-2 h-full justify-center items-center"
);

const EmptyText = clsx(
    "text-[#909090] text-[14px] font-normal"
);

// 카드 높이가 고정이라 행이 많으면 표만 스크롤된다 (챗봇과 같은 얇은 스크롤바)
const TableScroller = clsx(
    "flex flex-col gap-3",
    "min-h-0 overflow-y-auto",
    "[scrollbar-width:thin] [scrollbar-color:transparent_transparent]",
    "hover:[scrollbar-color:#3A3D47_transparent]",
    "[&::-webkit-scrollbar]:w-1.5",
    "[&::-webkit-scrollbar-track]:bg-transparent",
    "[&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-transparent",
    "hover:[&::-webkit-scrollbar-thumb]:bg-[#3A3D47]"
);

// 지역 방문자 카드의 표와 같은 규칙: 얇은 구분선, 숫자는 오른쪽 정렬 + 고정폭 숫자
const DataTable = clsx(
    "w-full border-collapse",
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

const TableFootRow = clsx(
    "border-t border-[#63717A]",
    "text-[#FFFFFF] font-medium"
);

const TableCell = clsx(
    "py-2.5 px-2 font-normal align-middle"
);

const KeyCell = clsx(
    "text-left"
);

const ValueCell = clsx(
    "text-right tabular-nums"
);

// key 는 한글 이름 + 실제 오퍼레이션 코드를 작게
const KeyLabel = clsx(
    "block text-[#FFFFFF]"
);

const KeyCode = clsx(
    "block text-[12px] text-[#909090] font-normal"
);

const FooterNote = clsx(
    "text-[12px] text-[#909090]"
);
