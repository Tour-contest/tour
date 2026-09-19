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
    { id: 2, to: "/operation", label: "호출 이력" },
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
                    className={({ isActive }) => (isActive ? AdminMenuStyle.active : AdminMenuStyle.normal)}
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

// 글자색은 상태별 스타일이 하나씩만 갖는다 — 같은 속성 클래스가 겹치면 CSS 순서에 따라 엉뚱한 쪽이 이긴다
const MenuBaseStyle = clsx(
    "px-3 py-2 box-border",
    "text-[16px] font-normal",
    "rounded-[8px]", 
    "select-none"
);

const MenuStyle = {
    active: clsx(MenuBaseStyle, "text-[#909090]", "bg-[#20232C]"),
    normal: clsx(MenuBaseStyle, "text-[#909090]", "hover:bg-[#20232C]"),
} as const;

// 관리자 메뉴: 보고 있는 페이지와 호버 모두 같은 강조색 글자 (관리자 입력 포커스색과 맞춤)
const AdminMenuStyle = {
    active: clsx(MenuBaseStyle, "text-[#309AE6]", "bg-[#20232C]"),
    normal: clsx(MenuBaseStyle, "text-[#909090] hover:text-[#309AE6]", "hover:bg-[#20232C]"),
} as const;