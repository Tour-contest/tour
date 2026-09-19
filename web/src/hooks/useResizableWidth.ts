import { useCallback, useRef, useState } from "react";
import useBodyDragState from "./useBodyDragState";

type ResizableWidthOptions = {
    min: number;
    max: number;
    initial: number;
    // 브라우저에 마지막 너비를 남길 키. 사용자마다 편한 폭이 달라 기기 단위로 기억한다
    storageKey?: string;
    // 키보드(← →) 한 번에 움직이는 픽셀
    keyboardStep?: number;
};

const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);

// 저장된 값이 없거나 범위를 벗어나면 기본값. 시크릿 창 등에서 storage 접근이 막혀도 동작한다
const readStoredWidth = (storageKey: string | undefined, fallback: number, min: number, max: number) => {
    if (!storageKey) return fallback;
    try {
        const stored = Number(localStorage.getItem(storageKey));
        return Number.isFinite(stored) && stored >= min && stored <= max ? stored : fallback;
    } catch {
        return fallback;
    }
};

const writeStoredWidth = (storageKey: string | undefined, width: number) => {
    if (!storageKey) return;
    try {
        localStorage.setItem(storageKey, String(width));
    } catch {
        // 저장 실패는 기능에 영향 없음
    }
};

// 가장자리를 끌어 너비를 바꾸는 패널(사이드바 등)용. 포인터 캡처로 손잡이 밖으로 나가도 드래그가 이어진다
const useResizableWidth = ({ min, max, initial, storageKey, keyboardStep = 16 }: ResizableWidthOptions) => {
    const [width, setWidth] = useState<number>(() => readStoredWidth(storageKey, initial, min, max));
    const [isResizing, setIsResizing] = useState<boolean>(false);
    // 드래그 시작 시점의 포인터 x · 너비. 이동량은 여기서부터 계산해야 흔들리지 않는다
    const dragStartRef = useRef<{ x: number; width: number } | null>(null);

    const commitWidth = useCallback((next: number) => {
        const clamped = clamp(next, min, max);
        setWidth(clamped);
        writeStoredWidth(storageKey, clamped);
    }, [min, max, storageKey]);

    const handlePointerDown = (e: React.PointerEvent<HTMLElement>) => {
        // 주 버튼(마우스 왼쪽 · 터치 · 펜)만
        if (e.button !== 0) return;
        e.preventDefault();
        dragStartRef.current = { x: e.clientX, width };
        e.currentTarget.setPointerCapture?.(e.pointerId);
        setIsResizing(true);
    };

    const handlePointerMove = (e: React.PointerEvent<HTMLElement>) => {
        const start = dragStartRef.current;
        if (!start) return;
        setWidth(clamp(start.width + (e.clientX - start.x), min, max));
    };

    const handlePointerUp = (e: React.PointerEvent<HTMLElement>) => {
        if (!dragStartRef.current) return;
        dragStartRef.current = null;
        e.currentTarget.releasePointerCapture?.(e.pointerId);
        setIsResizing(false);
        setWidth((current) => {
            writeStoredWidth(storageKey, current);
            return current;
        });
    };

    // 키보드로도 조절할 수 있어야 한다 (separator 역할). Home/End 는 최소/최대
    const handleKeyDown = (e: React.KeyboardEvent<HTMLElement>) => {
        const delta = e.key === "ArrowRight" ? keyboardStep
            : e.key === "ArrowLeft" ? -keyboardStep
            : e.key === "Home" ? min - width
            : e.key === "End" ? max - width
            : null;
        if (delta === null) return;
        e.preventDefault();
        commitWidth(width + delta);
    };

    const reset = () => commitWidth(initial);

    // 드래그 중엔 화면 어디서든 열 커서, 글자 드래그 선택 금지
    useBodyDragState(isResizing, "col-resize");

    return {
        width,
        isResizing,
        reset,
        // 손잡이 요소에 그대로 펼친다
        handleProps: {
            role: "separator" as const,
            "aria-orientation": "vertical" as const,
            "aria-valuemin": min,
            "aria-valuemax": max,
            "aria-valuenow": width,
            tabIndex: 0,
            onPointerDown: handlePointerDown,
            onPointerMove: handlePointerMove,
            onPointerUp: handlePointerUp,
            onPointerCancel: handlePointerUp,
            onKeyDown: handleKeyDown,
            onDoubleClick: reset,
        },
    };
};
export default useResizableWidth;
