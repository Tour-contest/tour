//react
import { useEffect, useState } from "react";
//router
import { NavLink, useLocation, useNavigate } from "react-router";
//api
import { clearSession } from "@/api/tokenManager";
//store
import { useAuthenticateStore } from "@/store/authenticate";
import { useAuthorityStore } from "@/store/authority";
import { useChatStore } from "@/store/chat";
import { useChatSessionStore } from "@/store/chatSession";
//hooks
import { useAuth, useChat } from "@/hooks/api";
//components
import { Menu } from "@/components";
import { ConfirmModal, LoadingIndicator } from "@/components/common";
import SidebarUserMenu from "./SidebarUserMenu";
import RecentlyChatList from "./RecentlyChatList";
//style
import clsx from "clsx";
//icon
// import NewChatIcon from "@/assets/icons/new_chat.svg?react";

// const ADMIN_MENUS = [
//     { to: "/admin", label: "관제 대시보드" },
//     { to: "/admin/users", label: "회원 관리" },
// ] as const;

// 회원 탈퇴는 소셜 로그인 유저에게만 있다. 관리자(local) · 개발 로그인(dev) 계정은 서버가 관리한다
const SOCIAL_PROVIDERS: ReadonlyArray<UserInfo["provider"]> = ["kakao"];

// 서비스 이탈이라 한 번 더 묻는다 — 되돌릴 수 없는 것들을 모달에 명시
const WITHDRAW_DESCRIPTIONS = [
    "계정과 대화 기록, 최근 본 관광지가 모두 삭제되고 복구할 수 없어요.",
    "카카오 계정 연결도 함께 해제됩니다.",
];

const Sidebar = () => {
    const [isWithdrawModalOpen, setIsWithdrawModalOpen] = useState<boolean>(false);
    const [isWithdrawing, setIsWithdrawing] = useState<boolean>(false);
    const [withdrawErrorMessage, setWithdrawErrorMessage] = useState<string | null>(null);

    const navigate = useNavigate();
    const { pathname } = useLocation();
    const { handleLogout, handleWithdrawMembership } = useAuth();
    const { handleDeleteChatSession } = useChat();

    const user = useAuthenticateStore((state) => state.user);
    const role = useAuthorityStore((state) => state.role);
    const sessions = useChatSessionStore((state) => state.sessions);
    const hasMoreSessions = useChatSessionStore((state) => state.hasMore);
    const isLoadingMoreSessions = useChatSessionStore((state) => state.isLoadingMore);
    const refreshSessions = useChatSessionStore((state) => state.refreshSessions);
    const loadMoreSessions = useChatSessionStore((state) => state.loadMoreSessions);
    const removeConversation = useChatStore((state) => state.removeConversation);

    const isAdmin = role === "admin";
    const canWithdraw = !isAdmin && user !== null && SOCIAL_PROVIDERS.includes(user.provider);

    useEffect(() => {
        if (isAdmin) return;
        refreshSessions();
    }, [isAdmin]);

    // 서버가 리프레시 토큰을 폐기해야 로그아웃이다. 로컬 정리는 /login 진입 시점에 이뤄진다
    const handleLogoutClick = async () => {
        await handleLogout();
        navigate("/login", { replace: true });
    };

    // 메뉴의 "회원 탈퇴"는 바로 요청하지 않고 모달을 연다 (댑스 하나 더)
    const handleWithdrawClick = () => {
        setWithdrawErrorMessage(null);
        setIsWithdrawModalOpen(true);
    };

    const handleWithdrawCancel = () => {
        if (isWithdrawing) return;
        setIsWithdrawModalOpen(false);
    };

    // 계정 · 대화 · 최근 본 관광지가 함께 삭제되고 복구할 수 없다 (명세). 카카오 연결 해제는 서버가 처리한다
    const handleWithdrawConfirm = async () => {
        if (isWithdrawing) return;
        setIsWithdrawing(true);
        setWithdrawErrorMessage(null);

        const { isSuccess, errorMessage } = await handleWithdrawMembership();
        setIsWithdrawing(false);

        if (!isSuccess) {
            // 모달은 열어둔 채 사유를 보여주고 재시도할 수 있게 한다
            setWithdrawErrorMessage(errorMessage ?? "탈퇴를 처리하지 못했어요. 잠시 후 다시 시도해주세요.");
            return;
        }

        // 명세: 로컬 토큰은 성공 응답을 받은 뒤에만 지운다 (실패했는데 지우면 되살릴 세션도 잃는다)
        setIsWithdrawModalOpen(false);
        clearSession();
        navigate("/login", { replace: true });
    };

    // 세션과 메시지가 함께 지워지고 복구할 수 없다 (명세)
    const handleDeleteSessionClick = async (sessionId: string) => {
        if (!window.confirm("이 대화를 삭제할까요? 삭제하면 복구할 수 없어요.")) return;

        const isDeleted = await handleDeleteChatSession(sessionId);
        if (!isDeleted) {
            window.alert("대화를 삭제하지 못했어요. 잠시 후 다시 시도해주세요.");
            return;
        }

        // 보고 있던 대화를 지웠다면 먼저 새 대화로 빠져나가야 사라진 대화 화면에 남지 않는다
        if (pathname === `/c/${sessionId}`) navigate("/", { replace: true });
        removeConversation(sessionId);
        refreshSessions();
    };

    return (
        <aside className={SideBarLayout}>
            <p className={clsx("px-[12px]", "text-[16px]", "font-black")}>
                널널{isAdmin && <span className={clsx("text-[12px]", "font-normal")}> admin</span>}
            </p>
            <Menu />
            {!isAdmin && (
                <div className={clsx("flex", "min-h-0", "flex-1", "flex-col", "gap-[4px]", "overflow-y-auto")}>
                    <RecentlyChatList />
                    {hasMoreSessions && (
                        <button
                            type="button"
                            onClick={loadMoreSessions}
                            disabled={isLoadingMoreSessions}
                            className={loadMoreButtonStyle}
                        >
                            {isLoadingMoreSessions ? <LoadingIndicator label="불러오는 중…" /> : "이전 대화 더 보기"}
                        </button>
                    )}
                </div>
            )}

            <div className={clsx("mt-auto")}>
                <SidebarUserMenu
                    user={user}
                    canWithdraw={canWithdraw}
                    onLogout={handleLogoutClick}
                    onWithdraw={handleWithdrawClick}
                />
            </div>

            <ConfirmModal
                isOpen={isWithdrawModalOpen}
                title="정말 탈퇴할까요?"
                descriptions={WITHDRAW_DESCRIPTIONS}
                confirmLabel="최종 회원 탈퇴"
                cancelLabel="취소"
                isPending={isWithdrawing}
                pendingLabel="탈퇴 처리 중"
                errorMessage={withdrawErrorMessage}
                isDanger
                onConfirm={handleWithdrawConfirm}
                onCancel={handleWithdrawCancel}
            />
        </aside>
    );
};
export default Sidebar;
//style configuration
const SideBarLayout = clsx(
    "w-60 h-full bg-[#1A1C22]",
    "flex flex-col gap-4",
    "shrink-0",
    "border-r border-[#e5e4e7]",
    "p-4 box-border",
);

const menuBaseStyle = clsx(
    "px-3 py-2 box-border",
    "text-[16px] text-[#909090] font-normal",
    "rounded-[8px]", 
    "select-none"
);

const MenuStyle = {
    active: clsx(menuBaseStyle, "bg-[#20232C]", "font-bold", "text-[#FFFFFF]"),
    normal: clsx(menuBaseStyle, "hover:bg-[#20232C]"),
} as const;

const sectionLabelStyle = clsx("px-[12px]", "text-[12px]", "text-[#6b6375]");

// 평소엔 숨기고 행에 마우스를 올리거나 키보드 포커스가 오면 보인다
const deleteButtonStyle = clsx(
    "shrink-0",
    "rounded-[6px]",
    "px-[8px]",
    "py-[4px]",
    "text-[12px]",
    "text-[#6b6375]",
    "opacity-0",
    "group-hover:opacity-100",
    "focus:opacity-100",
    "hover:bg-[#e9e7df]",
    "hover:text-[#ff3b30]",
);

// 목록 마지막 줄. 메뉴 항목과 같은 높이라 목록에 자연스럽게 이어진다
const loadMoreButtonStyle = clsx(
    menuBaseStyle,
    "text-left text-[#6b6375]",
    "hover:bg-[#f0eee7]",
    "disabled:opacity-60",
);
