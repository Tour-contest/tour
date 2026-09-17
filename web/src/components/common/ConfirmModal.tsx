import { useEffect, useId, useRef } from "react";
import { createPortal } from "react-dom";
import clsx from "clsx";
import LoadingIndicator from "./LoadingIndicator";

type ConfirmModalNeedProps = {
    isOpen: boolean;
    title: string;
    // 줄마다 <p> 로 그린다
    descriptions: string[];
    confirmLabel: string;
    cancelLabel?: string;
    // 확인 버튼을 누른 뒤 서버 응답을 기다리는 동안 — 버튼을 잠그고 닫히지 않게 한다
    isPending?: boolean;
    pendingLabel?: string;
    // 확인 요청이 실패했을 때 모달 안에 보여줄 문구 (모달은 열린 채로 재시도 가능)
    errorMessage?: string | null;
    isDanger?: boolean;
    onConfirm: () => void;
    onCancel: () => void;
};

// 되돌릴 수 없는 동작(회원 탈퇴 등) 앞에 한 번 더 묻는 모달.
// 취소 버튼에 먼저 포커스를 두고, Esc · 배경 클릭은 취소로 취급한다
const ConfirmModal = ({
    isOpen,
    title,
    descriptions,
    confirmLabel,
    cancelLabel = "취소",
    isPending = false,
    pendingLabel = "처리 중",
    errorMessage = null,
    isDanger = false,
    onConfirm,
    onCancel,
} : ConfirmModalNeedProps) => {
    const titleId = useId();
    const descriptionId = useId();
    const cancelRef = useRef<HTMLButtonElement | null>(null);

    useEffect(() => {
        if (!isOpen) return;

        cancelRef.current?.focus();

        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === "Escape" && !isPending) onCancel();
        };
        document.addEventListener("keydown", handleKeyDown);
        return () => document.removeEventListener("keydown", handleKeyDown);
    }, [isOpen, isPending, onCancel]);

    if (!isOpen) return null;

    const handleBackdropClick = () => {
        if (!isPending) onCancel();
    };

    return createPortal(
        <div className={Backdrop} onClick={handleBackdropClick}>
            <div
                role="dialog"
                aria-modal="true"
                aria-labelledby={titleId}
                aria-describedby={descriptionId}
                onClick={(e) => e.stopPropagation()}
                className={Dialog}
            >
                <h2 id={titleId} className={Title}>{title}</h2>
                <div id={descriptionId} className={Body}>
                    {descriptions.map((line) => (
                        <p key={line} className={Description}>{line}</p>
                    ))}
                </div>

                {errorMessage && <p role="alert" className={ErrorText}>{errorMessage}</p>}

                <div className={Actions}>
                    <button
                        ref={cancelRef}
                        type="button"
                        onClick={onCancel}
                        disabled={isPending}
                        className={clsx(ActionButton, CancelButton)}
                    >
                        {cancelLabel}
                    </button>
                    <button
                        type="button"
                        onClick={onConfirm}
                        disabled={isPending}
                        className={clsx(ActionButton, isDanger ? DangerButton : ConfirmButton)}
                    >
                        {isPending ? <LoadingIndicator label={pendingLabel} /> : confirmLabel}
                    </button>
                </div>
            </div>
        </div>,
        document.body,
    );
}
export default ConfirmModal;
//style configuration
// TODO: 스타일은 개발자 지시에 맞춰 교체 예정 — 지금은 배치만 잡아둔 최소 스타일
const Backdrop = clsx(
    "fixed inset-0 z-50",
    "flex items-center justify-center",
    "bg-[#00000066]",
    "p-4"
);

const Dialog = clsx(
    "flex flex-col gap-4",
    "w-full max-w-[360px]",
    "rounded-[12px]",
    "bg-white",
    "p-6",
    "shadow-lg",
    "animate-fade-in"
);

const Title = clsx(
    "text-[16px] font-bold"
);

const Body = clsx(
    "flex flex-col gap-1"
);

const Description = clsx(
    "text-[13px] text-[#6b6375]"
);

const ErrorText = clsx(
    "text-[12px] text-[#d03b3b]"
);

const Actions = clsx(
    "flex justify-end gap-2"
);

const ActionButton = clsx(
    "rounded-[8px]",
    "px-4 py-2",
    "text-[13px] font-semibold",
    "disabled:opacity-60"
);

const CancelButton = clsx(
    "bg-[#f0eee7]",
    "hover:bg-[#e9e7df]"
);

const ConfirmButton = clsx(
    "bg-[#1d1c1a] text-white",
    "hover:bg-[#3a3835]"
);

const DangerButton = clsx(
    "bg-[#d03b3b] text-white",
    "hover:bg-[#b23030]"
);
