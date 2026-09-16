import { useActionState } from "react";
import { Navigate } from "react-router";
import clsx from "clsx";
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";

// form action 으로 넘기면 React 가 트랜지션으로 감싸주므로 startTransition 이 필요 없다
const AdminLoginForm = () => {
    const { handleAdminLogin } = useAuth();

    const [adminLoginState, formAction, isPending] = useActionState(
        handleAdminLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    // 권한별 최종 목적지는 라우터 가드가 다시 정리한다
    if (adminLoginState.isSuccess) return <Navigate to="/" replace />;

    return <form action={formAction} className={AdminForm}>
        <div className={FieldGroup}>
            <label htmlFor="loginId" className={FieldLabel}>관리자 아이디</label>
            <input
                id="loginId"
                name="loginId"
                type="text"
                autoComplete="username"
                className={FieldInput}
            />
        </div>

        <div className={FieldGroup}>
            <label htmlFor="password" className={FieldLabel}>비밀번호</label>
            <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                className={FieldInput}
            />
        </div>

        {adminLoginState.errorMessage && <p className={ErrorMessage}>{adminLoginState.errorMessage}</p>}

        <button type="submit" disabled={isPending} className={SubmitButton}>
            {isPending ? "로그인 중…" : "로그인"}
        </button>
    </form>
}
export default AdminLoginForm;
//style configuration
const AdminForm = clsx(
    "flex flex-col gap-4"
);

const FieldGroup = clsx(
    "flex flex-col gap-2"
);

const FieldLabel = clsx(
    "text-[14px]"
);

const FieldInput = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "p-2"
);

const ErrorMessage = clsx(
    "text-[13px] text-[#ff3b30]"
);

const SubmitButton = clsx(
    "rounded-[8px]",
    "bg-[#222] text-white",
    "p-2",
    "disabled:opacity-50"
);
