import { useRef, useState } from "react";
//hooks
import useDismiss from "@/hooks/useDismiss";
//style
import clsx from "clsx";
//icon
import UserIcon from "@/assets/icons/user_icon.svg?react";
import SystemIcon from "@/assets/logo/system.svg?react";

type SidebarUserMenuNeedProps = {
    user: UserInfo | null;
    // 회원 탈퇴는 소셜 로그인 유저에게만 있다 (관리자 · 개발 로그인 계정은 서버가 관리)
    canWithdraw: boolean;
    onLogout: () => void;
    onWithdraw: () => void;
};

// 응답에 이메일이 없어 보조 줄에는 로그인 수단을 보여준다
const PROVIDER_LABEL: Record<UserInfo["provider"], string> = {
    kakao: "카카오 계정",
    local: "관리자 계정",
    dev: "개발 로그인",
};

// 사이드바 하단 유저 카드 + 옆의 시스템(설정) 아이콘.
// 아이콘을 누르면 계정 메뉴(로그아웃 · 회원 탈퇴)가 아이콘 위에 절대 위치로 떠서 사이드바 배치를 밀지 않는다. 카드 자체는 정보 표시만 한다
const SidebarUserMenu = ({ user, canWithdraw, onLogout, onWithdraw } : SidebarUserMenuNeedProps) => {
    const [isOpen, setIsOpen] = useState<boolean>(false);
    const rootRef = useRef<HTMLDivElement | null>(null);

    // 메뉴 바깥을 누르거나 Esc 를 누르면 닫힌다
    useDismiss({ isActive: isOpen, onDismiss: () => setIsOpen(false), containerRef: rootRef });

    const handleLogoutClick = () => {
        setIsOpen(false);
        onLogout();
    };

    const handleWithdrawClick = () => {
        setIsOpen(false);
        onWithdraw();
    };

    return <div ref={rootRef} className={UserArea}>
        <div className={UserRow}>
            {isOpen && (
                <div role="menu" aria-label="계정 메뉴" className={Menu}>
                    <button type="button" role="menuitem" onClick={handleLogoutClick} className={MenuItem}>
                        로그아웃
                    </button>
                    {canWithdraw && (
                        <button type="button" role="menuitem" onClick={handleWithdrawClick} className={clsx(MenuItem, MenuItemDanger)}>
                            회원 탈퇴
                        </button>
                    )}
                </div>
            )}

            <div className={UserCard}>
                <span aria-hidden="true" className={Avatar}>
                    <UserIcon className="w-5 h-5 text-[#FFFFFF]" />
                </span>
                <span className={UserText}>
                    <span className={UserName}>{user?.nickname ?? "여행자"}</span>
                    <span className={UserSub}>{user ? PROVIDER_LABEL[user.provider] : ""}</span>
                </span>
            </div>

            <button
                type="button"
                aria-label="계정 설정"
                aria-haspopup="menu"
                aria-expanded={isOpen}
                onClick={() => setIsOpen((prev) => !prev)}
                className={SettingsButton}
            >
                <SystemIcon className="w-6 h-6" />
            </button>
        </div>
    </div>
}
export default SidebarUserMenu;
//style configuration
// TODO: 스타일은 개발자 지시에 맞춰 교체 예정 — 지금은 배치만 잡아둔 최소 스타일
const UserArea = clsx(
    "border-t border-[#909090]",
    "p-[16px_20px] box-border"
);

// 메뉴의 기준점 — 메뉴는 이 행 바로 위에 뜬다
const UserRow = clsx(
    "relative",
    "flex items-center gap-1"
);

const UserCard = clsx(
    "flex items-center gap-3",
    "min-w-0 flex-1",
    "select-none"
);

const Avatar = clsx(
    "flex items-center justify-center shrink-0",
    "size-10.5",
    "rounded-full",
    "bg-[#20232C]"
);

const UserText = clsx(
    "flex flex-col min-w-0"
);

const UserName = clsx(
    "truncate",
    "text-[16px] text-[#FFFFFF] font-normal"
);

const UserSub = clsx(
    "truncate",
    "text-[12px] text-[#FFFFFF] font-normal"
);

const SettingsButton = clsx(
    "flex items-center justify-center shrink-0",
    "size-9",
    "rounded-[8px]",
    "text-[#6b6375]",
    "hover:bg-[#20232C]",
    "aria-expanded:bg-[#20232C]"
);

// 아이콘 쪽(오른쪽)에 맞춰 행 위로 떠오른다. 레이아웃 흐름에 없어서 열려도 위 내용을 밀지 않는다
const Menu = clsx(
    "absolute right-0 bottom-full z-20",
    "mb-2",
    "flex flex-col gap-1",
    "min-w-[160px]",
    "rounded-[12px]",
    "border border-[#63717A]",
    "bg-[#1A1C22]",
    "p-2 box-border",
    "shadow-md",
    "animate-fade-in"
);

const MenuItem = clsx(
    "rounded-[6px]",
    "px-[10px] py-[6px]",
    "text-left text-[15px] text-[#E4E4E4]",
    "hover:bg-[#20232C]"
);

const MenuItemDanger = clsx(
    "text-[#d03b3b]"
);
