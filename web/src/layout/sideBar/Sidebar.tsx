//react
import { useEffect, useState } from "react";
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
//components
import { Menu } from "@/components";
import { ConfirmModal, LoadingIndicator } from "@/components/common";
import SidebarUserMenu from "./SidebarUserMenu";
import RecentlyChatList from "./RecentlyChatList";
//style
import clsx from "clsx";
//icon
import MainLogoCharacter from '@/assets/logo/main_logo_character.svg?react';

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
    const { handleLogout, handleWithdrawMembership } = useAuth();
   
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

    return (
        <aside className={SideBarLayout}>
            <a className="p-[32px_28px_0px_28px]" href="/"><MainLogoCharacter className="w-10 h-10" /></a>
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
    "text-left text-[#6b6375]",
    "hover:bg-[#f0eee7]",
    "disabled:opacity-60",
);
