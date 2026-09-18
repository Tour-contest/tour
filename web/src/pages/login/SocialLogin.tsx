import { startTransition, useActionState } from "react";
import { Navigate } from "react-router";
import clsx from "clsx";
import { LoadingIndicator } from "@/components/common";
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";
import KakaoSocialIcon from "@/assets/icons/kakao_social_login_logo.svg?react";

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

type SocialLoginNeedProps = {
    providerData: ResponseProviderData | null;
};

const SocialLogin = ({ providerData } : SocialLoginNeedProps) => {
    const { handleDevLogin } = useAuth();

    const [devLoginState, dispatchDevLogin, isDevLoginPending] = useActionState(
        handleDevLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    // 인가 서버로 나가는 이동은 SPA 를 떠나는 실제 네비게이션이라 라우터가 아니라 location 으로 보낸다
    const handleKakaoLoginClick = (clientId: string) => {
        window.location.assign(buildKakaoAuthorizeUrl(clientId));
    };

    // form action 이 아닌 곳에서 dispatch 하면 트랜지션으로 감싸야 한다 — 안 그러면 isPending 이 갱신되지 않는다
    const handleDevLoginClick = () => {
        startTransition(() => dispatchDevLogin(DEV_LOGIN_NICKNAME));
    };

    if (devLoginState.isSuccess) return <Navigate to="/" replace />;

    return <div className={SocialSection}>
        {providerData === null && <LoadingIndicator label="로그인 수단 조회 중…" />}
        {providerData?.social.length === 0 && <p className={MutedMessage}>설정된 로그인 수단이 없습니다</p>}
        {
            providerData?.social.map((item) => {
                return <button
                    key={item.provider}
                    type="button"
                    onClick={() => handleKakaoLoginClick(item.client_id)}
                    className={KakaoButton}
                >
                    <KakaoSocialIcon className="w-7 h-7 fill-[#3A2818]"  /> 카카오 로그인
                </button>
            })
        }

        {providerData?.dev_login && (
            <>
                {devLoginState.errorMessage && <p className={ErrorMessage}>{devLoginState.errorMessage}</p>}
                <button
                    type="button"
                    onClick={handleDevLoginClick}
                    disabled={isDevLoginPending}
                    className={DevLoginButton}
                >
                    {isDevLoginPending ? "로그인 중…" : `개발자 로그인 (${DEV_LOGIN_NICKNAME})`}
                </button>
            </>
        )}
    </div>
}
export default SocialLogin;
//style configuration
const SocialSection = clsx(
    "flex flex-col gap-2"
);

const MutedMessage = clsx(
    "text-[13px] text-[#6b6375]"
);

const ErrorMessage = clsx(
    "text-[13px] text-[#ff3b30]"
);

const KakaoButton = clsx(
    "w-50 h-13.75 bg-[#fee500]",
    "flex gap-4 justify-center items-center",
    "rounded-full",
    "text-[18px] text-[#3A2818] font-medium",
    "cursor-pointer",
);

const DevLoginButton = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "p-2",
    "disabled:opacity-50"
);
