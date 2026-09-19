//react
import { useState } from "react";
//router
import { NavLink } from "react-router";
//store
import { useChatSessionStore } from "@/store/chatSession";
//hooks
import useDeleteChatSession from "../hooks/useDeleteChatSession";
//components
import ChatSessionsModal from "./ChatSessionsModal";
//style
import clsx from "clsx";
//icon
import CancelIcon from "@/assets/icons/cancel.svg?react";
import DownIcon from '@/assets/icons/down_icon.svg?react';
import UpIcon from '@/assets/icons/up_icon.svg?react';
import LearnMoreIcon from "@/assets/icons/learn_more.svg?react";

const RecentlyChatList = () => {
    const [isDrops, setIsDrops] = useState<boolean>(true);
    // "..." → 전체 대화 팝업 (페이지네이션)
    const [isAllSessionsOpen, setIsAllSessionsOpen] = useState<boolean>(false);
    const sessions = useChatSessionStore((state) => state.sessions);
    // 확인 → 삭제 → (보던 대화면) 이탈 → 목록 갱신
    const { deleteSession } = useDeleteChatSession();

    return <div className={RecentlyConversations}>
        <div className={RecentlyGroup}>
            <div className={RecentlyTitleGroup}>
                <h3 className={Title}>최근 대화</h3>
                <button onClick={() => setIsDrops(!isDrops)} className="select-none cursor-pointer">
                    { isDrops ? <DownIcon className="w-3 h-3 text-[#909090]" /> : 
                        <UpIcon className="w-3 h-3 text-[#909090]" /> }
                </button> 
            </div>
            <button
                type="button"
                aria-label="전체 대화 보기"
                aria-haspopup="dialog"
                onClick={() => setIsAllSessionsOpen(true)}
                className="select-none cursor-pointer"
            >
                <LearnMoreIcon className="w-3 text-[#909090]" />
            </button>
        </div>
        <ChatSessionsModal isOpen={isAllSessionsOpen} onClose={() => setIsAllSessionsOpen(false)} />
        <div className={ChatList}>
            {
                isDrops ? (
                    <div className={ChatGroup}>
                        {
                            sessions.length > 0 ? sessions.map((session) => (
                                <div key={session.id} className={ChatIndex}>
                                    <NavLink
                                        to={`/c/${session.id}`}
                                        draggable={false}
                                        onDragStart={(e) => e.preventDefault()}
                                        className={({ isActive }) =>
                                            clsx(isActive ? MenuStyle.active : MenuStyle.normal, "min-w-0", "flex-1", "truncate")
                                        }
                                    >
                                        {session.title ?? "새 대화"}
                                    </NavLink>
                                    <button
                                        type="button"
                                        onClick={() => deleteSession(session.id)}
                                        aria-label={`${session.title ?? "새 대화"} 삭제`}
                                        className={DeleteButtonStyle}
                                    >
                                        <CancelIcon className="w-2 h-2 fill-[#FFFFFF]" />
                                    </button>
                                </div>
                            )): <p>아직 대화가 없어요</p> 
                        }
                    </div>
                ) : null
            }
        </div>
    </div>
};
export default RecentlyChatList;
//style configuration
const RecentlyConversations = clsx(
    "flex flex-col gap-3 flex-1", "min-h-0 overflow-y-auto"
);

const Title = clsx(
    "text-[#909090] text-[14px] font-normal",
    "select-none"
);

const MenuBaseStyle = clsx(
    "px-3 py-2 box-border",
    "text-[18px] text-[#909090] font-normal",
    "rounded-[8px]", 
    "select-none"
);

const MenuStyle = {
    active: clsx(MenuBaseStyle, "bg-[#20232C]", "font-bold", "text-[#FFFFFF]"),
    normal: clsx(MenuBaseStyle, "hover:bg-[#20232C]"),
} as const;

const DeleteButtonStyle = clsx(
    "cursor-pointer",
    "shrink-0",
    "rounded-[6px]",
    "text-[#909090]",
    "opacity-0",
    "group-hover:opacity-100",
    "focus:opacity-100",
    "hover:text-[#FFFFFF]",
);

const RecentlyGroup = clsx(
    "p-[0px_28px] box-border",
    "flex items-center justify-between"
);

const RecentlyTitleGroup = clsx(
    "flex items-center gap-2"
);

const ChatList = clsx(
    "h-full overflow-y-auto",
    // 표준 속성 (Chrome 121+ · Edge · Firefox): 얇은 바, 평소엔 투명, 호버 시 배경에 맞춘 회색
    "[scrollbar-width:thin] [scrollbar-color:transparent_transparent]",
    "hover:[scrollbar-color:#3A3D47_transparent]",
    // Safari 는 아직 표준 속성을 안 읽어서 WebKit 전용 규칙을 같이 둔다 (Chrome 은 표준이 있으면 이쪽을 무시)
    "[&::-webkit-scrollbar]:w-1.5",
    "[&::-webkit-scrollbar-track]:bg-transparent",
    "[&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-transparent",
    "hover:[&::-webkit-scrollbar-thumb]:bg-[#3A3D47]",
);

const ChatGroup = clsx(
    "p-[0px_16px] box-border",
    "flex flex-col gap-1"
);

const ChatIndex = clsx(
    "group flex items-center gap-4"
);