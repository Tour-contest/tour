import { useActionState, useEffect, useState } from "react";
import clsx from "clsx";
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

const Login = () => {
    const { handleAdminLogin, handleDevLogin, handleSocialLogin, fetchAuthenticateProvider } = useAuth();

    const [providerData, setProviderData] = useState<ResponseProviderData | null>(null);

    const [adminLoginState, formAction, isPending] = useActionState(
        handleAdminLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    const [devLoginState, dispatchDevLogin, isDevLoginPending] = useActionState(
        handleDevLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    const [socialLoginState, dispatchSocialLogin, isSocialLoginPending] = useActionState(
        handleSocialLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    useEffect(() => {
        fetchAuthenticateProvider().then(setProviderData);
    }, []);

    // 카카오 인가 서버가 이 페이지로 돌아오면서 붙여준 code 를 잡아 콜백 API 호출
    useEffect(() => {
        const code = new URLSearchParams(window.location.search).get("code");
        if (!code) return;

        window.history.replaceState(null, "", window.location.pathname);
        dispatchSocialLogin({ provider: "kakao", code, redirectUri: REDIRECT_URI });
    }, []);

    const handleKakaoLoginClick = (clientId: string) => {
        window.location.assign(buildKakaoAuthorizeUrl(clientId));
    };

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
                    {socialLoginState.errorMessage && (
                        <p className={clsx("text-[13px]", "text-[#ff3b30]")}>
                            {socialLoginState.errorMessage}
                        </p>
                    )}

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
                            disabled={isSocialLoginPending}
                            onClick={() => handleKakaoLoginClick(item.client_id)}
                            className={clsx(
                                "rounded-[8px]",
                                "bg-[#fee500]",
                                "p-[8px]",
                                "disabled:opacity-50",
                            )}
                        >
                            {isSocialLoginPending ? "로그인 중…" : "카카오로 시작하기"}
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
};
export default Login;
