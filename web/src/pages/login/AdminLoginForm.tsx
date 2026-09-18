//react
import { useActionState } from "react";
//router
import { Navigate } from "react-router";
//hooks
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";
//style
import clsx from "clsx";

const AdminLoginForm = () => {
    const { handleAdminLogin } = useAuth();

    const [adminLoginState, formAction, isPending] = useActionState(
        handleAdminLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

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

        <div className="h-5 text-center">
            {adminLoginState.errorMessage && <p className={ErrorMessage}>{adminLoginState.errorMessage}</p>}
        </div>

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
    "text-[14px] text-[#b1bdc8] font-medium tracking-[1.4px]"
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
    "bg-[#309AE6]",
    "text-[#20232C] text-[18px] font-medium tracking-[2px]",
    "p-2 box-border",
    "disabled:opacity-50",
);
