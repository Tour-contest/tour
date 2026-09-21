// 회원 관리 화면의 표시 규칙 (명세: nickname → login_id → id 순으로 존재하는 값을 사용)

export const resolveUserLabel = (user: AdminUser) => {
    return user.nickname || user.login_id || user.id;
};

export const PROVIDER_LABEL: Record<AdminUser["provider"], string> = {
    kakao: "카카오",
    local: "관리자",
    dev: "개발",
};

export const STATUS_LABEL: Record<UserStatus, string> = {
    active: "정상",
    suspended: "정지",
};

export const ROLE_LABEL: Record<UserRole, string> = {
    admin: "관리자",
    user: "일반",
};

// KST ISO 8601 → "9/6 08:39". 목록에서 연도는 잘 안 보므로 생략하고, 툴팁에 원문을 둔다
export const formatDateTime = (iso: string | null) => {
    if (!iso) return "-";
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return iso;

    return `${date.getMonth() + 1}/${date.getDate()} ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
};

// locked_until 이 미래면 아직 잠긴 계정이다 (로그인 연속 실패)
export const isLocked = (user: AdminUser) => {
    if (!user.locked_until) return false;
    const until = new Date(user.locked_until).getTime();
    return !Number.isNaN(until) && until > Date.now();
};

// 제공자 · 상태 필터는 API 에 없어 받은 페이지 안에서만 거른다 — 화면에 그 한계를 표시한다
export type UserFilters = {
    provider: AdminUser["provider"] | "all";
    status: UserStatus | "all";
};

export const INITIAL_USER_FILTERS: UserFilters = {
    provider: "all",
    status: "all",
};

export const applyUserFilters = (users: AdminUser[], filters: UserFilters) => {
    return users.filter((user) => {
        if (filters.provider !== "all" && user.provider !== filters.provider) return false;
        if (filters.status !== "all" && user.status !== filters.status) return false;
        return true;
    });
};
