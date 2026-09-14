import { useActionState, useEffect, useState } from "react";
import { Navigate } from "react-router";
import clsx from "clsx";
import { clearSession } from "@/api/tokenManager";
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";

const DEV_LOGIN_NICKNAME = "테스터";
const KAKAO_AUTHORIZE_URL = "https://kauth.kakao.com/oauth/authorize";
// 카카오 디벨로퍼스 콘솔에 등록된 Redirect URI와 정확히 같아야 한다 (호스트가 window.location.origin과 다를 수 있어 env로 고정)
const REDIRECT_URI = import.meta.env.VITE_KAKAO_REDIRECT_URI;

const buildKakaoAuthorizeUrl = (clientId: string) => {
    const url = new URL(KAKAO_AUTHORIZE_URL);
    url.searchParams.set("client_id", clientId);
    url.searchParams.set("redirect_uri", REDIRECT_URI);
    url.searchParams.set("response_type", "code");
    return url.toString();
};

function Login() {
    const { handleAdminLogin, handleDevLogin, fetchAuthenticateProvider } = useAuth();

    const [providerData, setProviderData] = useState<ResponseProviderData | null>(null);

    const [adminLoginState, formAction, isPending] = useActionState(
        handleAdminLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    const [devLoginState, dispatchDevLogin, isDevLoginPending] = useActionState(
        handleDevLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    useEffect(() => {
        // 로그인 화면 진입 = 새 로그인의 시작점이므로 남아있는 세션을 먼저 비운다.
        // provider 조회보다 앞서야 만료된 토큰으로 불필요한 refresh 가 돌지 않는다
        clearSession();
        fetchAuthenticateProvider().then(setProviderData);
    }, []);

    const handleKakaoLoginClick = (clientId: string) => {
        window.location.assign(buildKakaoAuthorizeUrl(clientId));
    };

    // 권한별 최종 목적지는 라우터 가드가 다시 정리한다
    if (adminLoginState.isSuccess || devLoginState.isSuccess) return <Navigate to="/" replace />;

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

                <div className={clsx("flex", "flex-col", "gap-[8px]", "border-t-[1px]", "border-[#e5e4e7]", "pt-[16px]")}>
                    {providerData === null && (
                        <p className={clsx("text-[13px]", "text-[#6b6375]")}>로그인 수단 조회 중…</p>
                    )}
                    {providerData?.social.length === 0 && (
                        <p className={clsx("text-[13px]", "text-[#6b6375]")}>설정된 로그인 수단이 없습니다</p>
                    )}
                    {providerData?.social.map((item) => (
                        <button
                            key={item.provider}
                            type="button"
                            onClick={() => handleKakaoLoginClick(item.client_id)}
                            className={clsx(
                                "rounded-[8px]",
                                "bg-[#fee500]",
                                "p-[8px]",
                            )}
                        >
                            카카오로 시작하기
                        </button>
                    ))}

                    {providerData?.dev_login && (
                        <>
                            {devLoginState.errorMessage && (
                                <p className={clsx("text-[13px]", "text-[#ff3b30]")}>
                                    {devLoginState.errorMessage}
                                </p>
                            )}
                            <button
                                type="button"
                                onClick={() => dispatchDevLogin(DEV_LOGIN_NICKNAME)}
                                disabled={isDevLoginPending}
                                className={clsx(
                                    "rounded-[8px]",
                                    "border-[1px]",
                                    "border-[#b1bdc8]",
                                    "p-[8px]",
                                    "disabled:opacity-50",
                                )}
                            >
                                {isDevLoginPending ? "로그인 중…" : `개발자 로그인 (${DEV_LOGIN_NICKNAME})`}
                            </button>
                        </>
                    )}
                </div>
            </form>
        </div>
    );
}
export default Login;
