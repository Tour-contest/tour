import { useEffect, useId, useRef } from "react";
import { createPortal } from "react-dom";
import clsx from "clsx";
import useDismiss from "@/hooks/useDismiss";

type ModalNeedProps = {
    isOpen: boolean;
    title: string;
    // 요청 중처럼 닫히면 안 되는 동안 true — Esc · 배경 클릭 · 닫기 버튼을 막는다
    isLocked?: boolean;
    // 열릴 때 포커스를 둘 요소. 없으면 대화상자 자체에 둔다
    initialFocusRef?: React.RefObject<HTMLElement | null>;
    // 설명 영역 id (aria-describedby). 확인 모달처럼 본문이 곧 설명일 때 넘긴다
    describedById?: string;
    hasCloseButton?: boolean;
    size?: "sm" | "md";
    onClose: () => void;
    children: React.ReactNode;
};

// 화면 중앙 모달의 공용 껍데기: 배경 · 포커스 · Esc · 배경 클릭 · 제목. 내용은 children 으로 받는다
const Modal = ({
    isOpen,
    title,
    isLocked = false,
    initialFocusRef,
    describedById,
    hasCloseButton = false,
    size = "sm",
    onClose,
    children,
} : ModalNeedProps) => {
    const titleId = useId();
    const dialogRef = useRef<HTMLDivElement | null>(null);

    // 열릴 때 포커스를 안으로 옮긴다
    useEffect(() => {
        if (!isOpen) return;
        (initialFocusRef?.current ?? dialogRef.current)?.focus();
    }, [isOpen, initialFocusRef]);

    // Esc 로 닫기 (요청 중엔 잠금). 배경 클릭은 아래 onClick 에서
    useDismiss({ isActive: isOpen && !isLocked, onDismiss: onClose });

    if (!isOpen) return null;

    const handleBackdropClick = () => {
        if (!isLocked) onClose();
    };

    return createPortal(
        <div className={Backdrop} onClick={handleBackdropClick}>
            <div
                ref={dialogRef}
                role="dialog"
                aria-modal="true"
                aria-labelledby={titleId}
                aria-describedby={describedById}
                tabIndex={-1}
                onClick={(e) => e.stopPropagation()}
                className={clsx(Dialog, DialogSize[size])}
            >
                <div className={Header}>
                    <h2 id={titleId} className={Title}>{title}</h2>
                    {hasCloseButton && (
                        <button type="button" aria-label="닫기" disabled={isLocked} onClick={onClose} className={CloseButton}>
                            ×
                        </button>
                    )}
                </div>
                {children}
            </div>
        </div>,
        document.body,
    );
}
export default Modal;
//style configuration
const Backdrop = clsx(
    "fixed inset-0 z-50",
    "flex items-center justify-center",
    "bg-[#00000099]",
    "p-4"
);

// 대화 카드와 같은 어두운 톤. 배경은 화면보다 살짝 밝게, 테두리로 경계를 준다
const Dialog = clsx(
    "flex flex-col gap-4",
    "w-full",
    "rounded-[12px]",
    "border border-[#63717A] bg-[#333743]",
    "p-6",
    "shadow-[0_12px_40px_rgba(0,0,0,0.45)]",
    "text-[#FFFFFF]",
    "outline-none",
    "animate-fade-in"
);

const DialogSize = {
    sm: "max-w-[360px]",
    md: "max-w-[560px]",
} as const;

const Header = clsx(
    "flex items-center justify-between gap-3"
);

const Title = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const CloseButton = clsx(
    "flex items-center justify-center shrink-0",
    "size-8",
    "rounded-[8px]",
    "text-[20px] leading-none text-[#909090]",
    "hover:bg-[#1A1C22] hover:text-[#FFFFFF]",
    "cursor-pointer",
    "disabled:opacity-50"
);
