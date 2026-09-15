import { useEffect } from "react";
import { NavLink, useNavigate } from "react-router";
import clsx from "clsx";
import { useAuth } from "@/hooks/api";
import { useAuthenticateStore } from "@/store/authenticate";
import { useAuthorityStore } from "@/store/authority";
import { useChatSessionStore } from "@/store/chatSession";

const ADMIN_MENUS = [
    { to: "/admin", label: "관제 대시보드" },
    { to: "/admin/users", label: "회원 관리" },
] as const;

const asideStyle = clsx(
    "flex",
    "h-full",
    "w-[240px]",
    "shrink-0",
    "flex-col",
    "gap-[16px]",
    "border-r-[1px]",
    "border-[#e5e4e7]",
    "bg-[#faf9f5]",
    "p-[16px]",
    "box-border",
);

const menuBaseStyle = clsx("rounded-[8px]", "px-[12px]", "py-[8px]", "text-[14px]", "select-none");

const MenuStyle = {
    active: clsx(menuBaseStyle, "bg-[#e9e7df]", "font-bold"),
    normal: clsx(menuBaseStyle, "hover:bg-[#f0eee7]"),
} as const;

const sectionLabelStyle = clsx("px-[12px]", "text-[12px]", "text-[#6b6375]");

const Sidebar = () => {
    const navigate = useNavigate();
    const { handleLogout } = useAuth();
    const user = useAuthenticateStore((state) => state.user);
    const role = useAuthorityStore((state) => state.role);
    const sessions = useChatSessionStore((state) => state.sessions);
    const refreshSessions = useChatSessionStore((state) => state.refreshSessions);

    const isAdmin = role === "admin";

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
        <aside className={asideStyle}>
            <p className={clsx("px-[12px]", "text-[16px]", "font-black")}>
                널널{isAdmin && <span className={clsx("text-[12px]", "font-normal")}> admin</span>}
            </p>

            <nav className={clsx("flex", "flex-col", "gap-[4px]")}>
                {isAdmin ? (
                    ADMIN_MENUS.map((menu) => (
                        <NavLink
                            key={menu.to}
                            to={menu.to}
                            end
                            draggable={false}
                            onDragStart={(e) => e.preventDefault()}
                            className={({ isActive }) => (isActive ? MenuStyle.active : MenuStyle.normal)}
                        >
                            {menu.label}
                        </NavLink>
                    ))
                ) : (
                    <NavLink
                        to="/"
                        end
                        draggable={false}
                        onDragStart={(e) => e.preventDefault()}
                        className={({ isActive }) => (isActive ? MenuStyle.active : MenuStyle.normal)}
                    >
                        새 대화
                    </NavLink>
                )}
            </nav>

            {!isAdmin && (
                <div className={clsx("flex", "min-h-0", "flex-1", "flex-col", "gap-[4px]", "overflow-y-auto")}>
                    <p className={sectionLabelStyle}>Recently</p>
                    {sessions.length === 0 && <p className={sectionLabelStyle}>아직 대화가 없어요</p>}
                    {sessions.map((session) => (
                        <NavLink
                            key={session.id}
                            to={`/c/${session.id}`}
                            draggable={false}
                            onDragStart={(e) => e.preventDefault()}
                            className={({ isActive }) =>
                                clsx(isActive ? MenuStyle.active : MenuStyle.normal, "truncate")
                            }
                        >
                            {session.title ?? "새 대화"}
                        </NavLink>
                    ))}
                </div>
            )}

            <div className={clsx("mt-auto", "flex", "flex-col", "gap-[8px]", "border-t-[1px]", "border-[#e5e4e7]", "pt-[16px]")}>
                <div className={clsx("px-[12px]")}>
                    <p className={clsx("truncate", "text-[14px]")}>{user?.nickname ?? "여행자"}</p>
                    <p className={clsx("text-[12px]", "text-[#6b6375]")}>{user?.provider}</p>
                </div>
                <button
                    type="button"
                    onClick={handleLogoutClick}
                    className={clsx(menuBaseStyle, "border-[1px]", "border-[#b1bdc8]", "text-left")}
                >
                    로그아웃
                </button>
            </div>
        </aside>
    );
};
export default Sidebar;
