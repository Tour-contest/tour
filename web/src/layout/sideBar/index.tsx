//react
import { useEffect } from "react";
//router
import { useNavigate } from "react-router";
//api
import { clearSession } from "@/api/tokenManager";
//store
import { useAuthenticateStore } from "@/store/authenticate";
import { useAuthorityStore } from "@/store/authority";
import { useChatSessionStore } from "@/store/chatSession";
//hooks
import { useAuth } from "@/hooks/api";
import useResizableWidth from "@/hooks/useResizableWidth";
import useConfirmAction from "@/hooks/useConfirmAction";
//components
import { Menu } from "@/components";
import { ConfirmModal, LoadingIndicator } from "@/components/common";
import SidebarUserMenu from "./SidebarUserMenu";
import SidebarResizeHandle from "./SidebarResizeHandle";
import RecentlyChatList from "./RecentlyChatList";
//style
import clsx from "clsx";
//icon
import MainLogoCharacter from '@/assets/logo/main_logo_character.svg?react';

// 회원 탈퇴는 소셜 로그인 유저에게만 있다. 관리자(local) · 개발 로그인(dev) 계정은 서버가 관리한다
const SOCIAL_PROVIDERS: ReadonlyArray<UserInfo["provider"]> = ["kakao"];

// 오른쪽 가장자리를 끌어 너비를 바꿀 수 있다. 기본 240, 최대 400. 마지막 값은 브라우저에 기억
const SIDEBAR_WIDTH = { min: 240, max: 400, initial: 240 } as const;
const SIDEBAR_WIDTH_STORAGE_KEY = "sidebarWidth";

// 서비스 이탈이라 한 번 더 묻는다 — 되돌릴 수 없는 것들을 모달에 명시
const WITHDRAW_DESCRIPTIONS = [
    "계정과 대화 기록, 최근 본 관광지가 모두 삭제되고 복구할 수 없어요.",
    "카카오 계정 연결도 함께 해제됩니다.",
];

const Sidebar = () => {
    const navigate = useNavigate();
    const { handleLogout, handleWithdrawMembership } = useAuth();

    // 회원 탈퇴: 메뉴 → 확인 모달 → 요청 중 잠금 → 실패 시 모달 유지 → 성공 시에만 로컬 토큰 삭제 (명세) 후 로그인 화면.
    // 계정 · 대화 · 최근 본 관광지가 함께 삭제되고 복구할 수 없다. 카카오 연결 해제는 서버가 처리한다
    const withdraw = useConfirmAction<true>({
        perform: () => handleWithdrawMembership(),
        onSuccess: () => {
            clearSession();
            navigate("/login", { replace: true });
        },
        fallbackErrorMessage: "탈퇴를 처리하지 못했어요. 잠시 후 다시 시도해주세요.",
    });
    const { width, isResizing, handleProps } = useResizableWidth({ ...SIDEBAR_WIDTH, storageKey: SIDEBAR_WIDTH_STORAGE_KEY });

    const user = useAuthenticateStore((state) => state.user);
    const role = useAuthorityStore((state) => state.role);
    const hasMoreSessions = useChatSessionStore((state) => state.hasMore);
    const isLoadingMoreSessions = useChatSessionStore((state) => state.isLoadingMore);
    const refreshSessions = useChatSessionStore((state) => state.refreshSessions);
    const loadMoreSessions = useChatSessionStore((state) => state.loadMoreSessions);
    
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

    return (
        <aside style={{ width }} className={SideBarLayout}>
            <SidebarResizeHandle handleProps={handleProps} isResizing={isResizing} />
            <a className={LogoLink} href="/">
                <MainLogoCharacter className="w-10 h-10" />
                {/* 관리자 화면임을 로고 옆에 작게 표시 */}
                {isAdmin && <span className={AdminTag}>관리자</span>}
            </a>
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
                    onWithdraw={() => withdraw.request(true)}
                />
            </div>

            <ConfirmModal
                isOpen={withdraw.isOpen}
                title="정말 탈퇴할까요?"
                descriptions={WITHDRAW_DESCRIPTIONS}
                confirmLabel="최종 회원 탈퇴"
                cancelLabel="취소"
                isPending={withdraw.isPending}
                pendingLabel="탈퇴 처리 중"
                errorMessage={withdraw.errorMessage}
                isDanger
                onConfirm={withdraw.confirm}
                onCancel={withdraw.cancel}
            />
        </aside>
    );
};
export default Sidebar;
//style configuration
// 너비는 inline style (드래그 값). relative 는 오른쪽 손잡이의 기준
const LogoLink = clsx(
    "flex items-center gap-2",
    "p-[32px_28px_0px_28px]"
);

const AdminTag = clsx(
    "text-[12px] text-[#909090] font-normal",
    "select-none"
);

const SideBarLayout = clsx(
    "relative h-full bg-[#1A1C22]",
    "flex flex-col gap-4",
    "shrink-0",
);

const menuBaseStyle = clsx(
    "px-3 py-2 box-border",
    "text-[16px] text-[#909090] font-normal",
    "rounded-[8px]", 
    "select-none"
);

// 목록 마지막 줄. 메뉴 항목과 같은 높이라 목록에 자연스럽게 이어진다
const loadMoreButtonStyle = clsx(
    menuBaseStyle,
    "text-left text-[#909090]",
    "cursor-pointer",
    "hover:bg-[#20232C] hover:text-[#FFFFFF]",
    "disabled:opacity-60",
);
