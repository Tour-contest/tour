import { useState } from "react";
import clsx from "clsx";
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
                className={SearchInput}
            />
            <button type="submit" className={Button}>검색</button>
            {query && (
                <button type="button" onClick={handleClear} className={Button}>초기화</button>
            )}
        </form>

        <div className={FilterGroup}>
            <select
                aria-label="제공자 필터"
                value={filters.provider}
                onChange={(e) => onFiltersChange({ ...filters, provider: e.target.value as UserFilters["provider"] })}
                className={Select}
            >
                <option value="all">제공자 전체</option>
                {
                    (Object.keys(PROVIDER_LABEL) as AdminUser["provider"][]).map((provider) => {
                        return <option key={provider} value={provider}>{PROVIDER_LABEL[provider]}</option>
                    })
                }
            </select>
            <select
                aria-label="상태 필터"
                value={filters.status}
                onChange={(e) => onFiltersChange({ ...filters, status: e.target.value as UserFilters["status"] })}
                className={Select}
            >
                <option value="all">상태 전체</option>
                {
                    (Object.keys(STATUS_LABEL) as UserStatus[]).map((status) => {
                        return <option key={status} value={status}>{STATUS_LABEL[status]}</option>
                    })
                }
            </select>
            {/* API 에 필터가 없어 받은 페이지 안에서만 걸러진다 — 다른 페이지에 더 있을 수 있음을 알린다 */}
            {isFilterActive && <p className={Caveat}>지금 보는 페이지 안에서만 걸러져요</p>}
        </div>
    </div>
}
export default AdminUserFilters;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지금은 구조만
const Toolbar = clsx(
    "flex flex-wrap items-center justify-between gap-3"
);

const SearchForm = clsx(
    "flex items-center gap-2"
);

const SearchInput = clsx(
    "w-[240px]",
    "border border-[#b1bdc8] rounded-[8px]",
    "px-3 py-1.5",
    "text-[13px]"
);

const Button = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "px-3 py-1.5",
    "text-[12px]",
    "hover:bg-[#f4f3ec]"
);

const FilterGroup = clsx(
    "flex flex-wrap items-center gap-2"
);

const Select = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "px-2 py-1.5",
    "text-[13px]"
);

const Caveat = clsx(
    "text-[12px] text-[#6b6375]"
);
