import { useEffect, useLayoutEffect, useRef } from "react";

// 이 거리 안까지 위로 올리면 이전 묶음을 받는다
const LOAD_OLDER_THRESHOLD_PX = 80;

type ChatScrollOptions = {
    // 대화가 바뀌면 스크롤 기억을 초기화한다
    conversationKey: string | undefined;
    // 이전 묶음이 앞에 붙었는지 감지하는 기준 (메시지 배열 참조)
    messages: unknown;
    // 새 내용이 아래에 생겼는지 감지하는 기준 (마지막 메시지 key · 생성 중 초안)
    bottomFollowKey: unknown;
    canLoadOlder: boolean;
    onLoadOlder: () => void;
};

// 대화 목록의 스크롤 동작 세 가지:
// 1) 위로 올려 상단 근처에 닿으면 이전 묶음 요청  2) 앞에 붙은 높이만큼 스크롤을 내려 보던 자리 고정  3) 새 내용이 아래에 생기면 맨 아래로 따라가기
const useChatScroll = ({ conversationKey, messages, bottomFollowKey, canLoadOlder, onLoadOlder }: ChatScrollOptions) => {
    const scrollContainerRef = useRef<HTMLDivElement | null>(null);
    const scrollAnchorRef = useRef<HTMLDivElement | null>(null);
    // 이전 묶음을 앞에 붙이기 직전의 스크롤 높이. 붙인 뒤 그만큼 내려서 보던 자리를 유지한다
    const pendingScrollHeightRef = useRef<number | null>(null);
    const lastScrollTopRef = useRef<number>(0);

    // 대화가 바뀌면 이전 대화의 스크롤 기억을 버린다
    useEffect(() => {
        pendingScrollHeightRef.current = null;
        lastScrollTopRef.current = 0;
    }, [conversationKey]);

    // 이전 묶음이 앞에 붙으면 내용이 아래로 밀리므로, 늘어난 높이만큼 스크롤을 내려 보던 위치를 고정한다.
    // 그리기 직후 페인트 전에 맞춰야 화면이 튀지 않는다
    useLayoutEffect(() => {
        const container = scrollContainerRef.current;
        const previousHeight = pendingScrollHeightRef.current;
        if (!container || previousHeight === null) return;

        container.scrollTop += container.scrollHeight - previousHeight;
        pendingScrollHeightRef.current = null;
    }, [messages]);

    // 맨 아래로 따라가는 건 새 내용이 아래에 생겼을 때만이다. 위에 이전 묶음이 붙을 때는 마지막 메시지가 그대로라 움직이지 않는다
    useEffect(() => {
        scrollAnchorRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [bottomFollowKey]);

    const requestOlderMessages = () => {
        if (!canLoadOlder) return;

        pendingScrollHeightRef.current = scrollContainerRef.current?.scrollHeight ?? null;
        onLoadOlder();
    };

    // 위로 올리는 중에 맨 위 근처에 닿으면 이전 묶음을 받는다.
    // 아래로 내려가는 스크롤(맨 아래 따라가기 · 위치 보정)에는 반응하지 않아야 열자마자 이전 묶음이 불려오지 않는다
    const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
        const { scrollTop } = e.currentTarget;
        const isScrollingUp = scrollTop < lastScrollTopRef.current;
        lastScrollTopRef.current = scrollTop;

        if (isScrollingUp && scrollTop <= LOAD_OLDER_THRESHOLD_PX) requestOlderMessages();
    };

    return { scrollContainerRef, scrollAnchorRef, handleScroll, requestOlderMessages };
};
export default useChatScroll;
