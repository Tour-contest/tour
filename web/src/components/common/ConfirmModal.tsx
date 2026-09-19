import { useId, useRef } from "react";
import clsx from "clsx";
import LoadingIndicator from "./LoadingIndicator";
import Modal from "./Modal";

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
// 취소 버튼에 먼저 포커스를 두고, Esc · 배경 클릭은 취소로 취급한다 (공용 Modal 위에 얹는다)
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
    const descriptionId = useId();
    const cancelRef = useRef<HTMLButtonElement | null>(null);

    return <Modal
        isOpen={isOpen}
        title={title}
        isLocked={isPending}
        initialFocusRef={cancelRef}
        describedById={descriptionId}
        onClose={onCancel}
    >
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
    </Modal>
}
export default ConfirmModal;
//style configuration
const Body = clsx(
    "flex flex-col gap-1"
);

const Description = clsx(
    "text-[14px] text-[#D8D8D8]"
);

const ErrorText = clsx(
    "text-[12px] text-[#FF6B6B]"
);

const Actions = clsx(
    "flex justify-end gap-2"
);

const ActionButton = clsx(
    "rounded-[8px]",
    "px-4 py-2",
    "text-[14px] font-medium",
    "cursor-pointer",
    "disabled:opacity-60 disabled:cursor-not-allowed"
);

const CancelButton = clsx(
    "border border-[#63717A] text-[#FFFFFF]",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]"
);

// 확인은 앱 강조색, 글자는 어두운 색
const ConfirmButton = clsx(
    "bg-[#6FC1FC] text-[#1A1C22]",
    "hover:bg-[#A3F1F9]"
);

const DangerButton = clsx(
    "bg-[#d03b3b] text-[#FFFFFF]",
    "hover:bg-[#b23030]"
);
