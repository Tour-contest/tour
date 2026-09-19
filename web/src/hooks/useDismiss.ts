import { useEffect, useRef } from "react";

type DismissOptions = {
    // 열려 있을 때만 리스너를 건다
    isActive: boolean;
    onDismiss: () => void;
    // 이 요소 바깥을 누르면 닫는다. 없으면 바깥 클릭은 보지 않는다 (Esc 만)
    containerRef?: React.RefObject<HTMLElement | null>;
};

// 팝업 · 메뉴 · 모달의 "닫기" 공통 동작: Esc, (있다면) 바깥 클릭.
// onDismiss 는 최신 함수를 ref 로 들고 있어 매 렌더마다 리스너를 다시 달지 않는다
const useDismiss = ({ isActive, onDismiss, containerRef }: DismissOptions) => {
    const onDismissRef = useRef(onDismiss);
    // 렌더 중 ref 를 만지지 않고(React Compiler 규칙) 커밋 뒤에 최신 함수로 바꿔 둔다
    useEffect(() => {
        onDismissRef.current = onDismiss;
    });

    useEffect(() => {
        if (!isActive) return;

        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === "Escape") onDismissRef.current();
        };
        const handlePointerDown = (e: PointerEvent) => {
            if (containerRef && !containerRef.current?.contains(e.target as Node)) onDismissRef.current();
        };

        document.addEventListener("keydown", handleKeyDown);
        if (containerRef) document.addEventListener("pointerdown", handlePointerDown);
        return () => {
            document.removeEventListener("keydown", handleKeyDown);
            if (containerRef) document.removeEventListener("pointerdown", handlePointerDown);
        };
    }, [isActive, containerRef]);
};
export default useDismiss;
