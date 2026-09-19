import { useState } from "react";
import clsx from "clsx";
import { ConfirmModal, LogoLoading, Pagination } from "@/components/common";
import { useAdmin, useUser } from "@/hooks/api";
import useAsyncData from "@/hooks/useAsyncData";
import useConfirmAction from "@/hooks/useConfirmAction";
import AdminUserFilters from "./AdminUserFilters";
import AdminUserTable from "./AdminUserTable";
import { INITIAL_USER_FILTERS, STATUS_LABEL, applyUserFilters, resolveUserLabel, type UserFilters } from "./utils/userDisplay";

// 명세 기본값 50 (1~200)
const PAGE_SIZE = 50;

// 차단/해제 확인 모달의 대상
type StatusChangeRequest = {
    user: AdminUser;
    nextStatus: UserStatus;
};

// 회원 관리 (SB-06 STEP 2). 목록 · 검색(서버) · 제공자/상태 필터(화면) · 차단/해제.
// "오늘 대화 수" · 차단 사유 · 이메일은 API 에 없어 뺐다
function AdminUsers() {
    const { fetchUsers } = useUser();
    const { handleChangeUserStatus } = useAdmin();

    const [query, setQuery] = useState<string>("");
    const [offset, setOffset] = useState<number>(0);
    const [filters, setFilters] = useState<UserFilters>(INITIAL_USER_FILTERS);

    // 검색어 · offset 이 바뀌면 다시 받고, 늦게 온 이전 응답은 버린다
    const { data, isLoading, hasError, reload } = useAsyncData(
        `${query}|${offset}`,
        () => fetchUsers({ q: query || undefined, limit: PAGE_SIZE, offset }),
    );

    // 차단/해제: 확인 모달 → 요청 중 잠금 → 실패 시 모달 유지 → 성공 시 같은 조건으로 재조회 (명세)
    const statusChange = useConfirmAction<StatusChangeRequest>({
        perform: async ({ user, nextStatus }) => ({ isSuccess: await handleChangeUserStatus(user.id, nextStatus) }),
        onSuccess: reload,
        fallbackErrorMessage: "상태를 바꾸지 못했어요. 잠시 후 다시 시도해주세요.",
    });
    const pendingUserId = statusChange.isPending ? statusChange.target?.user.id ?? null : null;

    // 명세: 검색어를 바꾸면 offset 을 0 으로 되돌린다
    const handleSearch = (nextQuery: string) => {
        setQuery(nextQuery);
        setOffset(0);
    };

    const page = data?.page ?? null;
    const users = data?.items ?? [];
    const isFilterActive = filters.provider !== "all" || filters.status !== "all";
    const visibleUsers = isFilterActive ? applyUserFilters(users, filters) : users;

    const pageStart = page ? page.offset + 1 : 0;
    const pageEnd = page ? page.offset + users.length : 0;
    // 서버가 total 을 주므로 번호 페이지네이션이 된다 (전체 대화 팝업 · 호출 이력과 같은 규칙)
    const currentPage = Math.floor(offset / PAGE_SIZE);
    const pageCount = page ? Math.max(1, Math.ceil(page.total / PAGE_SIZE)) : 1;

    return (
        <div className={Page}>
            <div className={Header}>
                <h1 className={Title}>회원 관리</h1>
                {page && <p className={Muted}>전체 {page.total.toLocaleString()}명</p>}
            </div>

            <div className={Section}>
                {/* 호출 이력처럼 필터를 카드 안 맨 위에 둔다 */}
                <AdminUserFilters
                    query={query}
                    onSearch={handleSearch}
                    filters={filters}
                    onFiltersChange={setFilters}
                    isFilterActive={isFilterActive}
                />

                {isLoading && (
                    <div className={CenterNote}>
                        <LogoLoading label="회원 목록을 불러오는 중…" />
                    </div>
                )}
                {hasError && (
                    <div className={CenterNote}>
                        <p className={ErrorText}>회원 목록을 불러오지 못했어요.</p>
                        <button type="button" onClick={reload} className={Button}>다시 시도</button>
                    </div>
                )}
                {!isLoading && !hasError && users.length === 0 && (
                    <p className={clsx(CenterNote, Muted)}>{query ? `'${query}' 에 해당하는 회원이 없어요` : "회원이 없어요"}</p>
                )}
                {!isLoading && !hasError && users.length > 0 && (
                    <>
                        {visibleUsers.length === 0 ? (
                            <p className={clsx(CenterNote, Muted)}>이 페이지에는 조건에 맞는 회원이 없어요. 다음 페이지를 확인해보세요</p>
                        ) : (
                            <AdminUserTable
                                users={visibleUsers}
                                pendingUserId={pendingUserId}
                                onRequestStatusChange={(user, nextStatus) => statusChange.request({ user, nextStatus })}
                            />
                        )}

                        <div className={Footer}>
                            <p className={Muted}>
                                {pageStart.toLocaleString()}–{pageEnd.toLocaleString()} / {page?.total.toLocaleString()}
                                {isFilterActive && ` (이 페이지에서 ${visibleUsers.length}명 표시)`}
                            </p>
                            <Pagination page={currentPage} pageCount={pageCount} onChange={(next) => setOffset(next * PAGE_SIZE)} label="회원 목록 페이지" />
                        </div>
                    </>
                )}
            </div>

            {/* 정지는 그 회원의 이후 요청이 전부 403 이 된다 — 한 번 더 묻는다 */}
            <ConfirmModal
                isOpen={statusChange.isOpen}
                title={statusChange.target?.nextStatus === "suspended" ? "이 회원을 차단할까요?" : "차단을 해제할까요?"}
                descriptions={statusChange.target ? [
                    `${resolveUserLabel(statusChange.target.user)} (${statusChange.target.user.id})`,
                    statusChange.target.nextStatus === "suspended"
                        ? "차단하면 이 회원의 요청이 모두 거부돼요. 이미 발급된 토큰은 만료까지 유효해서 바로 끊기지는 않아요."
                        : "해제하면 다시 정상적으로 이용할 수 있어요.",
                ] : []}
                confirmLabel={statusChange.target ? `${STATUS_LABEL[statusChange.target.nextStatus]}으로 변경` : ""}
                cancelLabel="취소"
                isPending={statusChange.isPending}
                pendingLabel="변경 중"
                errorMessage={statusChange.errorMessage}
                isDanger={statusChange.target?.nextStatus === "suspended"}
                onConfirm={statusChange.confirm}
                onCancel={statusChange.cancel}
            />
        </div>
    );
}
export default AdminUsers;
//style configuration
// 호출 이력과 같은 어두운 톤 · 얇은 호버 스크롤바 (index.css 의 scrollbar-thin-hover)
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
