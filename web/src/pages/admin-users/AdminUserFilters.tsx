import { useState } from "react";
import clsx from "clsx";
import DownIcon from "@/assets/icons/down_icon.svg?react";
import { PROVIDER_LABEL, STATUS_LABEL, type UserFilters } from "./utils/userDisplay";

type AdminUserFiltersNeedProps = {
    // 서버 검색어 (닉네임 · 로그인 ID 부분 일치). 제출할 때만 요청이 나간다
    query: string;
    onSearch: (query: string) => void;
    // 화면 필터 (현재 페이지 안에서만)
    filters: UserFilters;
    onFiltersChange: (filters: UserFilters) => void;
    isFilterActive: boolean;
};

// 검색은 Enter/버튼으로 제출해야 요청이 나간다 — 타이핑마다 부르면 관리자 API 를 낭비한다
const AdminUserFilters = ({ query, onSearch, filters, onFiltersChange, isFilterActive } : AdminUserFiltersNeedProps) => {
    const [draft, setDraft] = useState<string>(query);

    const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        onSearch(draft.trim());
    };

    const handleClear = () => {
        setDraft("");
        onSearch("");
    };

    return <div className={Toolbar}>
        <form onSubmit={handleSubmit} className={SearchForm}>
            <input
                type="search"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                placeholder="닉네임 · 로그인 ID 검색"
                aria-label="회원 검색"
                className={clsx(Control, SearchInput)}
            />
            <button type="submit" className={Button}>검색</button>
            {query && (
                <button type="button" onClick={handleClear} className={Button}>초기화</button>
            )}
        </form>

        <div className={FilterGroup}>
            {/* 브라우저 기본 화살표 대신 우리 아이콘 — 좌우 여백을 맞춘다 (호출 이력과 같은 방식) */}
            <span className={SelectWrap}>
                <select
                    aria-label="제공자 필터"
                    value={filters.provider}
                    onChange={(e) => onFiltersChange({ ...filters, provider: e.target.value as UserFilters["provider"] })}
                    className={clsx(Control, Select)}
                >
                    <option value="all">제공자 전체</option>
                    {
                        (Object.keys(PROVIDER_LABEL) as AdminUser["provider"][]).map((provider) => {
                            return <option key={provider} value={provider}>{PROVIDER_LABEL[provider]}</option>
                        })
                    }
                </select>
                <DownIcon aria-hidden="true" className={SelectArrow} />
            </span>
            <span className={SelectWrap}>
                <select
                    aria-label="상태 필터"
                    value={filters.status}
                    onChange={(e) => onFiltersChange({ ...filters, status: e.target.value as UserFilters["status"] })}
                    className={clsx(Control, Select)}
                >
                    <option value="all">상태 전체</option>
                    {
                        (Object.keys(STATUS_LABEL) as UserStatus[]).map((status) => {
                            return <option key={status} value={status}>{STATUS_LABEL[status]}</option>
                        })
                    }
                </select>
                <DownIcon aria-hidden="true" className={SelectArrow} />
            </span>
            {/* API 에 필터가 없어 받은 페이지 안에서만 걸러진다 — 다른 페이지에 더 있을 수 있음을 알린다 */}
            {isFilterActive && <p className={Caveat}>지금 보는 페이지 안에서만 걸러져요</p>}
        </div>
    </div>
}
export default AdminUserFilters;
//style configuration
const Toolbar = clsx(
    "flex flex-wrap items-center justify-between gap-3"
);

const SearchForm = clsx(
    "flex items-center gap-2"
);

// 어두운 배경의 입력: 관리자 로그인 입력과 같은 포커스 링
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

const SearchInput = clsx(
    "w-[240px]",
    "placeholder:text-[#909090]"
);

const Button = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1.5",
    "text-[12px] text-[#FFFFFF]",
    "cursor-pointer",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]"
);

const FilterGroup = clsx(
    "flex flex-wrap items-center gap-2"
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

const Caveat = clsx(
    "text-[12px] text-[#909090]"
);
