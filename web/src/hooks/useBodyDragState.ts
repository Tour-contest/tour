import { useEffect } from "react";

// 드래그(크기 조절 · 끌어 옮기기)하는 동안 화면 어디서든 같은 커서를 보이고 글자가 드래그 선택되지 않게 한다.
// 끝나면 body 스타일을 원래대로 되돌린다
const useBodyDragState = (isDragging: boolean, cursor: string) => {
    useEffect(() => {
        if (!isDragging) return;

        const { cursor: previousCursor, userSelect: previousUserSelect } = document.body.style;
        document.body.style.cursor = cursor;
        document.body.style.userSelect = "none";
        return () => {
            document.body.style.cursor = previousCursor;
            document.body.style.userSelect = previousUserSelect;
        };
    }, [isDragging, cursor]);
};
export default useBodyDragState;
