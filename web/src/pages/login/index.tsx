import { useActionState } from "react";
import { isAxiosError } from "axios";
import clsx from "clsx";
import { useAuth } from "@/hooks/api";
import type { ErrorResponse } from "@/types/error";

type AdminLoginState = {
    errorMessage: string | null;
};

const INITIAL_ADMIN_LOGIN_STATE: AdminLoginState = {
    errorMessage: null,
};

const Login = () => {
    const { requestAdminLogin } = useAuth();

    const handleAdminLogin = async (
        _previousState: AdminLoginState,
        formData: FormData,
    ): Promise<AdminLoginState> => {
        const loginId = formData.get("loginId")?.toString() ?? "";
        const password = formData.get("password")?.toString() ?? "";

        try {
            await requestAdminLogin(loginId, password);
            return { errorMessage: null };
        } catch (e) {
            console.error(e);

            if (isAxiosError<ErrorResponse>(e) && e.response?.data.message) {
                return { errorMessage: e.response.data.message };
            }
            return { errorMessage: "로그인에 실패했습니다. 잠시 후 다시 시도해주세요." };
        }
    };

    const [adminLoginState, formAction, isPending] = useActionState(
        handleAdminLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    return (
        <div className={clsx("flex", "h-[100vh]", "items-center", "justify-center")}>
            <form
                action={formAction}
                className={clsx(
                    "flex",
                    "w-[320px]",
                    "flex-col",
                    "gap-[16px]",
                    "rounded-[12px]",
                    "border-[1px]",
                    "border-[#e5e4e7]",
                    "p-[24px]",
                    "box-border",
                )}
            >
                <h2 className={clsx("text-[20px]", "font-bold", "text-center")}>
                    관리자 로그인
                </h2>

                <div className={clsx("flex", "flex-col", "gap-[8px]")}>
                    <label htmlFor="loginId" className={clsx("text-[14px]")}>
                        관리자 아이디
                    </label>
                    <input
                        id="loginId"
                        name="loginId"
                        type="text"
                        autoComplete="username"
                        className={clsx("rounded-[8px]", "border-[1px]", "border-[#b1bdc8]", "p-[8px]")}
                    />
                </div>

                <div className={clsx("flex", "flex-col", "gap-[8px]")}>
                    <label htmlFor="password" className={clsx("text-[14px]")}>
                        비밀번호
                    </label>
                    <input
                        id="password"
                        name="password"
                        type="password"
                        autoComplete="current-password"
                        className={clsx("rounded-[8px]", "border-[1px]", "border-[#b1bdc8]", "p-[8px]")}
                    />
                </div>

                {adminLoginState.errorMessage && (
                    <p className={clsx("text-[13px]", "text-[#ff3b30]")}>
                        {adminLoginState.errorMessage}
                    </p>
                )}

                <button
                    type="submit"
                    disabled={isPending}
                    className={clsx(
                        "rounded-[8px]",
                        "bg-[#222]",
                        "p-[8px]",
                        "text-white",
                        "disabled:opacity-50",
                    )}
                >
                    {isPending ? "로그인 중…" : "로그인"}
                </button>
            </form>
        </div>
    );
};
export default Login;
