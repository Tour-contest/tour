//api
import { useChat } from "@/hooks/api";
//router
import { NavLink, useLocation, useNavigate } from "react-router";
//store
import { useChatSessionStore } from "@/store/chatSession";
import { useChatStore } from "@/store/chat";
//style
import clsx from "clsx";
//icon
import CancelIcon from "@/assets/icons/cancel.svg?react";

const RecentlyChatList = () => {
    const navigate = useNavigate();
    const { pathname } = useLocation();

    const removeConversation = useChatStore((state) => state.removeConversation);
    const sessions = useChatSessionStore((state) => state.sessions);
    const refreshSessions = useChatSessionStore((state) => state.refreshSessions);
    const { handleDeleteChatSession } = useChat();

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

    return <div className={RecentlyConversations}>
        <h3 className={Title}>최근 대화</h3>
        <div className="flex flex-col gap-5">
            {
                sessions.length > 0 ? sessions.map((session) => (
                    <div key={session.id} className="group flex items-center gap-3">
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
                            onClick={() => handleDeleteSessionClick(session.id)}
                            aria-label={`${session.title ?? "새 대화"} 삭제`}
                            className={DeleteButtonStyle}
                        >
                            <CancelIcon className="w-5 h-5 fill-[#FFFFFF]" />
                        </button>
                    </div>
                )): <p>아직 대화가 없어요</p> 
            }
        </div>
    </div>
};
export default RecentlyChatList;
//style configuration
const RecentlyConversations = clsx(
    "flex flex-col gap-1 flex-1", "min-h-0 overflow-y-auto"
);

const Title = clsx(
    "text-[#909090] text-[16px] font-normal"
);

const MenuBaseStyle = clsx(
    "px-3 py-2 box-border",
    "text-[16px] text-[#909090] font-normal",
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
    "text-[12px]",
    "text-[#909090]",
    "opacity-0",
    "group-hover:opacity-100",
    "focus:opacity-100",
    "hover:text-[#FFFFFF]",
);