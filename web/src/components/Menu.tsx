//router
import { NavLink } from "react-router";
//store
import { useAuthorityStore } from "@/store/authority";
//style
import clsx from "clsx";
//icons
import NewChatIcon from "@/assets/icons/new_chat.svg?react";

const ADMIN_MENUS = [
    { id: 0, to: "/admin", label: "관제 대시보드" },
    { id: 1, to: "/admin/users", label: "회원 관리" },
] as const;

const Menu = () => {
    const role = useAuthorityStore((state) => state.role);

    const isAdmin = role === "admin";

    return <nav className={MenuWrapper}>
        {
            isAdmin ? ADMIN_MENUS.map((menu) => (
                <NavLink
                    key={menu.id}
                    to={menu.to}
                    end
                    draggable={false}
                    onDragStart={(e) => e.preventDefault()}
                    className={({ isActive }) => (isActive ? MenuStyle.active : MenuStyle.normal)}
                >
                    {menu.label}
                </NavLink>
            )) : (
                <NavLink
                    to="/"
                    end
                    draggable={false}
                    onDragStart={(e) => e.preventDefault()}
                    className={({ isActive }) => clsx("flex gap-3.25 items-center"  ,isActive ? MenuStyle.active : MenuStyle.normal)} 
                >
                    <NewChatIcon className="w-5 h-5 text-[#FFFFFF]" />
                    <p className="text-[18px] text-[#FFFFFF] font-normal">새 채팅</p>
                </NavLink>
            )
        }
    </nav>
};
export default Menu;
//style configuration
const MenuWrapper = clsx(
    "p-[0px_16px] box-border",
    "flex flex-col gap-1",
);

const MenuBaseStyle = clsx(
    "px-3 py-2 box-border",
    "text-[16px] text-[#909090] font-normal",
    "rounded-[8px]", 
    "select-none"
);

const MenuStyle = {
    active: clsx(MenuBaseStyle, "bg-[#20232C]"),
    normal: clsx(MenuBaseStyle, "hover:bg-[#20232C]"),
} as const;