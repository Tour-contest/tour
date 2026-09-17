import { startTransition, useActionState, useEffect, useRef } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router";
import clsx from "clsx";
import { LoadingIndicator } from "@/components/common";
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";

const REDIRECT_URI = import.meta.env.VITE_KAKAO_REDIRECT_URI;

// 소셜 인가 서버가 돌아오는 착지 라우트 (/oauth/:provider/callback) — code 를 받아 콜백 API 호출만 담당한다
function SocialCallback() {
    const { provider } = useParams<{ provider: string }>();
    const navigate = useNavigate();
    const { handleSocialLogin } = useAuth();

    // 인가 코드는 1회용이라 StrictMode 의 effect 2회 실행으로 재사용되면 두 번째 교환이 실패한다
    const hasRequestedRef = useRef(false);

    const [socialLoginState, dispatchSocialLogin] = useActionState(
        handleSocialLogin,
        INITIAL_ADMIN_LOGIN_STATE,
    );

    useEffect(() => {
        if (hasRequestedRef.current) return;

        const code = new URLSearchParams(window.location.search).get("code");
        if (!provider || !code) {
            navigate("/login", { replace: true });
            return;
        }

        hasRequestedRef.current = true;
        // effect 안의 dispatch 도 트랜지션 밖이라 감싸야 한다
        startTransition(() => dispatchSocialLogin({ provider, code, redirectUri: REDIRECT_URI }));
    }, []);

    // 권한별 최종 목적지는 라우터 가드가 다시 정리한다
    if (socialLoginState.isSuccess) return <Navigate to="/" replace />;

    return (
        <div className={clsx("flex", "h-[100vh]", "flex-col", "items-center", "justify-center", "gap-[12px]")}>
            {socialLoginState.errorMessage ? (
                <>
                    <p className={clsx("text-[13px]", "text-[#ff3b30]")}>{socialLoginState.errorMessage}</p>
                    <Link to="/login" className={clsx("text-[13px]", "underline")}>
                        로그인으로 돌아가기
                    </Link>
                </>
            ) : (
                <LoadingIndicator label="로그인 처리 중…" />
            )}
        </div>
    );
}
export default SocialCallback;
