//features
import { PROVIDER_LABEL, PROVIDER_OPTIONS, todayKst, type ProviderFilter } from "./utils/operationLog";
//style
import clsx from "clsx";
//icons
import DownIcon from "@/assets/icons/down_icon.svg?react";

type OperationFiltersNeedProps = {
    // "" 이면 오늘 (서버 기본값)
    day: string;
    onDayChange: (day: string) => void;
    provider: ProviderFilter;
    onProviderChange: (provider: ProviderFilter) => void;
};

// 날짜 · 제공자는 서버 파라미터라 바꾸면 바로 다시 받는다
const OperationFilters = ({ day, onDayChange, provider, onProviderChange } : OperationFiltersNeedProps) => {
    return <div className={Toolbar}>
        <label className={Field}>
            <span className={FieldLabel}>날짜</span>
            <input
                type="date"
                value={day}
                max={todayKst()}
                onChange={(e) => onDayChange(e.target.value)}
                aria-label="조회 일자"
                className={Control}
            />
        </label>
        {day && (
            <button type="button" onClick={() => onDayChange("")} className={Button}>오늘</button>
        )}

        <label className={Field}>
            <span className={FieldLabel}>제공자</span>
            {/* 브라우저 기본 화살표는 오른쪽 끝에 붙어 좌우 여백이 안 맞는다 — 감추고 우리 아이콘을 왼쪽 여백과 같은 자리에 둔다 */}
            <span className={SelectWrap}>
                <select
                    value={provider}
                    onChange={(e) => onProviderChange(e.target.value as ProviderFilter)}
                    aria-label="제공자 필터"
                    className={clsx(Control, Select)}
                >
                    <option value="all">전체</option>
                    {
                        PROVIDER_OPTIONS.map((option) => {
                            return <option key={option} value={option}>{PROVIDER_LABEL[option]}</option>
                        })
                    }
                </select>
                <DownIcon aria-hidden="true" className={SelectArrow} />
            </span>
        </label>
    </div>
}
export default OperationFilters;
//style configuration
const Toolbar = clsx(
    "flex flex-wrap items-center gap-3"
);

const Field = clsx(
    "flex items-center gap-2"
);

const FieldLabel = clsx(
    "text-[12px] text-[#909090]"
);

// 어두운 배경의 입력: 관리자 로그인 입력과 같은 포커스 링. 달력 아이콘도 어둡게 (color-scheme)
const Control = clsx(
    "border border-[#63717A] rounded-[8px]",
    "bg-[#20232C] text-[#FFFFFF] text-[14px]",
    "px-3 py-1.5",
    "[color-scheme:dark]",
    "outline-none",
    "transition-[border-color,box-shadow] duration-150",
    "focus:border-[#309AE6]",
    "focus:shadow-[0_0_0_1.4px_#309AE6,0_0_10px_rgba(48,154,230,0.35)]"
);

const SelectWrap = clsx(
    "relative inline-flex"
);

// 왼쪽 여백(px-3) 과 같은 12px 을 화살표 오른쪽에도 두고, 글자가 화살표를 덮지 않게 오른쪽 안쪽 여백을 넓힌다
const Select = clsx(
    "appearance-none",
    "pr-9",
    "cursor-pointer"
);

const SelectArrow = clsx(
    "pointer-events-none",
    "absolute right-3 top-1/2 -translate-y-1/2",
    "w-3 h-2 text-[#909090]"
);

const Button = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1",
    "text-[12px] text-[#FFFFFF]",
    "cursor-pointer",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]"
);
