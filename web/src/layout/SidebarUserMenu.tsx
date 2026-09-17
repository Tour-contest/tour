import { useEffect, useRef, useState } from "react";
import clsx from "clsx";

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
    useEffect(() => {
        if (!isOpen) return;

        const handlePointerDown = (e: PointerEvent) => {
            if (!rootRef.current?.contains(e.target as Node)) setIsOpen(false);
        };
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === "Escape") setIsOpen(false);
        };

        document.addEventListener("pointerdown", handlePointerDown);
        document.addEventListener("keydown", handleKeyDown);
        return () => {
            document.removeEventListener("pointerdown", handlePointerDown);
            document.removeEventListener("keydown", handleKeyDown);
        };
    }, [isOpen]);

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
                    <svg viewBox="0 0 24 24" className={Icon}>
                        <circle cx="12" cy="8" r="4" fill="none" stroke="currentColor" strokeWidth="1.8" />
                        <path d="M4 20c0-3.6 3.6-6 8-6s8 2.4 8 6" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                    </svg>
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
                <svg viewBox="0 0 24 24" aria-hidden="true" className={Icon}>
                    <circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" strokeWidth="1.8" />
                    <path
                        d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.6"
                        strokeLinejoin="round"
                    />
                </svg>
            </button>
        </div>
    </div>
}
export default SidebarUserMenu;
//style configuration
// TODO: 스타일은 개발자 지시에 맞춰 교체 예정 — 지금은 배치만 잡아둔 최소 스타일
const UserArea = clsx(
    "border-t border-[#e5e4e7]",
    "pt-4"
);

// 메뉴의 기준점 — 메뉴는 이 행 바로 위에 뜬다
const UserRow = clsx(
    "relative",
    "flex items-center gap-1"
);

const UserCard = clsx(
    "flex items-center gap-3",
    "min-w-0 flex-1",
    "rounded-[8px]",
    "px-3 py-2",
    "select-none"
);

const Avatar = clsx(
    "flex items-center justify-center shrink-0",
    "size-9",
    "rounded-full",
    "bg-[#e9e7df] text-[#6b6375]"
);

const Icon = clsx(
    "size-5"
);

const UserText = clsx(
    "flex flex-col min-w-0"
);

const UserName = clsx(
    "truncate",
    "text-[14px] font-semibold"
);

const UserSub = clsx(
    "truncate",
    "text-[12px] text-[#6b6375]"
);

const SettingsButton = clsx(
    "flex items-center justify-center shrink-0",
    "size-9",
    "rounded-[8px]",
    "text-[#6b6375]",
    "hover:bg-[#f0eee7]",
    "aria-expanded:bg-[#e9e7df]"
);

// 아이콘 쪽(오른쪽)에 맞춰 행 위로 떠오른다. 레이아웃 흐름에 없어서 열려도 위 내용을 밀지 않는다
const Menu = clsx(
    "absolute right-0 bottom-full z-20",
    "mb-2",
    "flex flex-col gap-1",
    "min-w-[160px]",
    "rounded-[8px]",
    "border border-[#e5e4e7]",
    "bg-white",
    "p-1",
    "shadow-md",
    "animate-fade-in"
);

const MenuItem = clsx(
    "rounded-[6px]",
    "px-3 py-2",
    "text-left text-[13px]",
    "hover:bg-[#f0eee7]"
);

const MenuItemDanger = clsx(
    "text-[#d03b3b]"
);
