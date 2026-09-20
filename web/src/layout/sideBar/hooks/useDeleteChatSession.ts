import { useLocation, useNavigate } from "react-router";
import { useChat } from "@/hooks/api";
import { useChatStore } from "@/store/chat";
import { useChatSessionStore } from "@/store/chatSession";

// 대화 삭제 흐름: 확인 → 삭제 API → (보고 있던 대화였으면) 새 대화로 이탈 → 대화 칸 제거 → 목록 갱신.
// 세션과 메시지가 함께 지워지고 복구할 수 없다 (명세). 404 는 이미 없는 세션이라 성공으로 본다 (useChat)
const useDeleteChatSession = () => {
    const navigate = useNavigate();
    const { pathname } = useLocation();
    const { handleDeleteChatSession } = useChat();
    const removeConversation = useChatStore((state) => state.removeConversation);
    const refreshSessions = useChatSessionStore((state) => state.refreshSessions);

    const deleteSession = async (sessionId: string) => {
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

    return { deleteSession };
};
export default useDeleteChatSession;
