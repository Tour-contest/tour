//feature
import type { AdminDashboardData } from "./index"
import { formatTokens, predictExhaustionTime } from "./utils/dashboard";
//style
import clsx from "clsx";
//icons
import WarningIcon from "@/assets/logo/warning.svg?react";

type TourApiMonitorNeedProps = {
    dashboard: AdminDashboardData;
};

const TourApiMonitor = ({ dashboard } : TourApiMonitorNeedProps) => {
    const { quota, error_rate, llm } = dashboard.apiCalls as ApiCallsData;

    const usedRate = quota.limit > 0 ? quota.used_today / quota.limit : 0;
    const exhaustionTime = predictExhaustionTime(quota);

    const matchedRate = dashboard.mapping && dashboard.mapping.total > 0
        ? (dashboard.mapping.matched / dashboard.mapping.total) * 100
        : null;

    const KPIGroup = [
        {
            id: 0,
            title: "TourAPI 호출",
            discription: <div className="flex items-baseline gap-1">
                <p className="text-[36px] text-[#46A8EE] font-medium">{quota.used_today.toLocaleString()}</p>
                <p className="text-[22px] text-[#8E8E8E] font-normal">/</p>
                <p className="text-[22px] text-[#8E8E8E] font-normal">{quota.limit.toLocaleString()}</p>
            </div>
        },
        {
            id: 1,
            title: "LLM 호출 · 토큰",
            discription: <div className="flex items-baseline gap-1">
                <p className="text-[36px] text-[#46A8EE] font-medium">{llm.calls}</p>
                <p className="text-[22px] text-[#8E8E8E] font-normal">·</p>
                <p className="text-[22px] text-[#8E8E8E] font-normal">{formatTokens(llm.prompt + llm.completion)}</p>
            </div>
        },
        {
            id: 2,
            title: "오류율",
            discription: <div className="flex items-baseline gap-1">
                <p className="text-[36px] text-[#46A8EE] font-medium">{(error_rate * 100).toFixed(1)}</p>
                <p className="text-[22px] text-[#8E8E8E] font-normal">%</p>
            </div>
        },
        {
            id: 3,
            title: "집중률 매칭 성공률",
            discription: <div className="flex items-baseline gap-1">
                <p className="text-[36px] text-[#46A8EE] font-medium">{matchedRate === null ? "-" : matchedRate.toFixed(1)}</p>
                <p className="text-[22px] text-[#8E8E8E] font-normal">%</p>
            </div>
        }
    ]

    return <section className={InterfaceLayout}>
        <div className={WarningTextGroup}>
            <WarningIcon className="w-6" />
            <p className={WarningText}>TourAPI 할당량 {Math.round(usedRate * 100)}% 사용{exhaustionTime && ` — 이 추세면 ${exhaustionTime} 소진`}</p>
        </div>
        <div className={MonitorStatus}>
            {
                KPIGroup.map((kpi) => {
                    return <div key={kpi.id} className={KPIContext}>
                        <h2 className={KPIContextTitle}>{kpi.title}</h2>
                        {kpi.discription}
                    </div>
                })
            }
        </div>
    </section>
};
export default TourApiMonitor;
//style configuration
const InterfaceLayout = clsx(
    "w-full bg-[#333743]",
    "flex flex-col gap-5",
    "rounded-[10px]",
    "p-[22px_32px] box-border"
);

const WarningTextGroup = clsx(
    "flex items-center gap-2.5"
);

const WarningText = clsx(
    "text-[18px] text-[#46A8EE] font-normal"
);

// 좁아지면 (페이지 폭 940px 미만 — index.tsx 의 @container 기준) 4개가 2×2 로 쌓인다.
// 항목 폭을 절반으로 잡아 줄바꿈시키므로 가로 간격은 두지 않고 세로 간격만 준다
const MonitorStatus = clsx(
    "flex flex-wrap items-center justify-between gap-y-6"
);

const KPIContext = clsx(
    "flex flex-col gap-2.5",
    "basis-1/2 @min-[940px]:basis-auto"
);

const KPIContextTitle = clsx(
    "text-[21px] text-[#FFFFFF] font-bold"
);