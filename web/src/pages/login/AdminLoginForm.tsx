//react
import { useActionState } from "react";
//router
import { Navigate } from "react-router";
//hooks
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";
//style
import clsx from "clsx";
//icons
import UserIcon from "@/assets/icons/user_fill.svg?react";
import PasswordIcon from "@/assets/icons/password_fill.svg?react";

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
            <div className="relative h-full flex">
                <input
                    id="loginId"
                    name="loginId"
                    type="text"
                    autoComplete="username"
                    className={FieldInput}
                    placeholder="아이디를 입력해주세요."
                />
                <UserIcon className="absolute left-[12px] top-1/2 -translate-y-1/2 w-5 h-5 text-[#FFFFFF]" />
            </div>
        </div>

        <div className={FieldGroup}>
            <label htmlFor="password" className={FieldLabel}>비밀번호</label>
            <div className="relative h-full flex">
                <input
                    id="password"
                    name="password"
                    type="password"
                    autoComplete="current-password"
                    className={FieldInput}
                    placeholder="비밀번호를 입력해주세요."
                />
                <PasswordIcon className="absolute left-[12px] top-1/2 -translate-y-1/2 w-5 h-5 text-[#FFFFFF]" />
            </div>
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

// 포커스: 기본 outline 대신 테두리색 + 같은 색의 얇은 링(그림자, 레이아웃 안 밀림). 챗봇 입력창과 같은 방식
const FieldInput = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "p-[8px_8px_8px_40px] box-border",
    "text-[#FFFFFF] text-[16px] font-normal",
    "outline-none",
    "transition-[border-color,box-shadow] duration-150",
    "focus:border-[#309AE6]",
    "focus:shadow-[0_0_0_1.4px_#309AE6,0_0_10px_rgba(48,154,230,0.35)]",
    // 브라우저 자동완성이 배경을 연파랑으로 덮는 것을 막는다: 안쪽 그림자 1000px 로 카드 배경색을 다시 깔고 글자색을 고정.
    // 포커스 상태에서는 그 안쪽 그림자 위에 포커스 링을 같이 얹는다 (box-shadow 는 하나만 적용되므로 합쳐서 쓴다)
    "autofill:shadow-[inset_0_0_0_1000px_#20232C]",
    "autofill:[-webkit-text-fill-color:#FFFFFF]",
    "autofill:caret-white",
    "focus:autofill:shadow-[inset_0_0_0_1000px_#20232C,0_0_0_1.4px_#309AE6,0_0_10px_rgba(48,154,230,0.35)]",
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
