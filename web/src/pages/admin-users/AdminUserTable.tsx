import clsx from "clsx";
import { PROVIDER_LABEL, ROLE_LABEL, STATUS_LABEL, formatDateTime, isLocked, resolveUserLabel } from "./utils/userDisplay";

type AdminUserTableNeedProps = {
    users: AdminUser[];
    // 지금 상태 변경 요청이 나가 있는 회원. 그 행의 버튼만 잠근다
    pendingUserId: string | null;
    onRequestStatusChange: (user: AdminUser, nextStatus: UserStatus) => void;
};

// SB-06 STEP 2 표. "오늘 대화 수" 컬럼은 API 에 없어 뺐다
const AdminUserTable = ({ users, pendingUserId, onRequestStatusChange } : AdminUserTableNeedProps) => {
    return <table className={Table}>
        <caption className="sr-only">회원 목록</caption>
        <thead>
            <tr className={HeadRow}>
                <th scope="col" className={Cell}>사용자</th>
                <th scope="col" className={Cell}>제공자</th>
                <th scope="col" className={Cell}>권한</th>
                <th scope="col" className={Cell}>가입일</th>
                <th scope="col" className={Cell}>마지막 로그인</th>
                <th scope="col" className={Cell}>상태</th>
                <th scope="col" className={clsx(Cell, ActionCell)}>관리</th>
            </tr>
        </thead>
        <tbody>
            {
                users.map((user) => {
                    const isAdmin = user.role === "admin";
                    const isPending = pendingUserId === user.id;
                    const nextStatus: UserStatus = user.status === "active" ? "suspended" : "active";

                    return <tr key={user.id} className={Row}>
                        <td className={Cell}>
                            <span className={UserLabel}>{resolveUserLabel(user)}</span>
                            {/* 닉네임이 없어 id 로 보일 때 헷갈리지 않게 id 를 항상 보조로 둔다 */}
                            <span className={Muted}>{user.id}</span>
                        </td>
                        <td className={Cell}>{PROVIDER_LABEL[user.provider]}</td>
                        <td className={Cell}>{ROLE_LABEL[user.role]}</td>
                        <td className={Cell} title={user.created_at ?? undefined}>{formatDateTime(user.created_at)}</td>
                        <td className={Cell} title={user.last_login_at ?? undefined}>{formatDateTime(user.last_login_at)}</td>
                        <td className={Cell}>
                            <span className={clsx(StatusBadge, user.status === "suspended" ? StatusSuspended : StatusActive)}>
                                {STATUS_LABEL[user.status]}
                            </span>
                            {isLocked(user) && (
                                <span className={clsx(StatusBadge, StatusLocked)} title={`잠금 해제 ${formatDateTime(user.locked_until)}`}>
                                    잠김
                                </span>
                            )}
                        </td>
                        <td className={clsx(Cell, ActionCell)}>
                            {/* 관리자 계정은 서버가 수동 관리한다 — 화면에서 정지시키면 되돌릴 사람이 없을 수 있다 */}
                            {isAdmin ? (
                                <span className={Muted}>-</span>
                            ) : (
                                <button
                                    type="button"
                                    disabled={isPending}
                                    onClick={() => onRequestStatusChange(user, nextStatus)}
                                    className={clsx(ActionButton, nextStatus === "suspended" && ActionDanger)}
                                >
                                    {isPending ? "처리 중…" : nextStatus === "suspended" ? "차단" : "해제"}
                                </button>
                            )}
                        </td>
                    </tr>
                })
            }
        </tbody>
    </table>
}
export default AdminUserTable;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지금은 구조만
const Table = clsx(
    "w-full border-collapse",
    "text-[13px]"
);

const HeadRow = clsx(
    "border-b border-[#e1e0d9]",
    "text-[12px] text-[#6b6375]"
);

const Row = clsx(
    "border-b border-[#e1e0d9] last:border-b-0",
    "hover:bg-[#faf9f5]"
);

const Cell = clsx(
    "py-2 pr-3 text-left font-normal align-middle"
);

const ActionCell = clsx(
    "text-right"
);

const UserLabel = clsx(
    "block truncate max-w-[200px] font-semibold"
);

const Muted = clsx(
    "block text-[11px] text-[#6b6375]"
);

const StatusBadge = clsx(
    "inline-flex items-center",
    "rounded-full",
    "px-2 py-0.5",
    "text-[12px]",
    "mr-1"
);

const StatusActive = clsx(
    "bg-[#e9f7ec] text-[#1a6b3a]"
);

const StatusSuspended = clsx(
    "bg-[#fdeaea] text-[#a12b2b]"
);

const StatusLocked = clsx(
    "bg-[#fff4e0] text-[#8a5a00]"
);

const ActionButton = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "px-3 py-1",
    "text-[12px]",
    "hover:bg-[#f4f3ec]",
    "disabled:opacity-60"
);

const ActionDanger = clsx(
    "text-[#d03b3b]"
);
