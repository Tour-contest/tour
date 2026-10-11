import { useState } from "react";

type ActionResult = {
    isSuccess: boolean;
    errorMessage?: string | null;
};

type ConfirmActionOptions<T> = {
    // 확인을 눌렀을 때 실제로 실행할 요청
    perform: (target: T) => Promise<ActionResult>;
    onSuccess?: (target: T) => void;
    // 서버가 문구를 주지 않았을 때 모달에 보일 기본 문구
    fallbackErrorMessage: string;
};

// "되돌릴 수 없는 동작 앞에 한 번 더 묻는" 흐름의 공통 뼈대 (ConfirmModal 과 짝):
// request(대상) → 모달 열림 → confirm() 요청 중 잠금 → 실패하면 모달 유지 + 문구 → 성공하면 닫고 onSuccess.
// 회원 탈퇴 · 회원 차단/해제처럼 대상만 다른 흐름이 이 하나를 쓴다
const useConfirmAction = <T>({ perform, onSuccess, fallbackErrorMessage }: ConfirmActionOptions<T>) => {
    const [target, setTarget] = useState<T | null>(null);
    const [isPending, setIsPending] = useState<boolean>(false);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);

    const request = (nextTarget: T) => {
        setErrorMessage(null);
        setTarget(nextTarget);
    };

    const cancel = () => {
        if (isPending) return;
        setTarget(null);
    };

    const confirm = async () => {
        if (target === null || isPending) return;

        setIsPending(true);
        setErrorMessage(null);

        const result = await perform(target);
        setIsPending(false);

        if (!result.isSuccess) {
            // 모달은 열어둔 채 사유를 보여주고 재시도할 수 있게 한다
            setErrorMessage(result.errorMessage ?? fallbackErrorMessage);
            return;
        }

        setTarget(null);
        onSuccess?.(target);
    };

    return {
        target,
        isOpen: target !== null,
        isPending,
        errorMessage,
        request,
        cancel,
        confirm,
    };
};
export default useConfirmAction;
