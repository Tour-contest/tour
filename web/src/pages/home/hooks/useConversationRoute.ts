import { useEffect } from "react";
import { useNavigate, useParams } from "react-router";
import { useChatStore, EMPTY_CONVERSATION, NEW_CONVERSATION_KEY } from "@/store/chat";

// URL 이 대화를 소유한다 — 사이드바에서 고른 대화(/c/:sessionId), 없으면 새 대화(/).
// 여기서 (1) URL 에 맞는 대화 칸을 열고 (2) 새 대화가 서버 id 를 받으면 주소만 교체한다
const useConversationRoute = () => {
    const navigate = useNavigate();
    const { sessionId } = useParams<{ sessionId: string }>();

    const promotedSessionId = useChatStore((state) => state.promotedSessionId);
    const openConversation = useChatStore((state) => state.openConversation);
    const prepareNewConversation = useChatStore((state) => state.prepareNewConversation);
    const clearPromotedSession = useChatStore((state) => state.clearPromotedSession);

    // 새 대화가 방금 서버 id 를 받았다면 URL 이 바뀌기 전 한 프레임도 옮겨간 칸을 읽는다 (빈 화면 깜빡임 방지)
    const activeKey = sessionId ?? promotedSessionId ?? NEW_CONVERSATION_KEY;
    const conversation = useChatStore((state) => state.conversations[activeKey]) ?? EMPTY_CONVERSATION;

    // store 액션은 참조가 고정이라 의존성에 넣어도 sessionId 가 바뀔 때만 실행된다
    useEffect(() => {
        if (sessionId) openConversation(sessionId);
        else prepareNewConversation();
    }, [sessionId, openConversation, prepareNewConversation]);

    // 새 대화가 서버 id 를 받으면 주소만 교체한다 — 같은 칸을 계속 읽으므로 이력을 다시 부르지 않는다
    useEffect(() => {
        if (sessionId) {
            clearPromotedSession();
            return;
        }
        if (promotedSessionId) navigate(`/c/${promotedSessionId}`, { replace: true });
    }, [sessionId, promotedSessionId, clearPromotedSession, navigate]);

    return { sessionId, activeKey, conversation };
};
export default useConversationRoute;
