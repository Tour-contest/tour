import { startTransition, useActionState, useEffect, useRef } from "react";
import { useNavigate, useParams } from "react-router";
import { useAuth, INITIAL_ADMIN_LOGIN_STATE } from "@/hooks/api";
import { KAKAO_REDIRECT_URI } from "@/pages/login/utils/kakaoAuth";

// 소셜 인가 서버가 돌아온 착지(/oauth/:provider/callback)에서 code 를 딱 한 번 서버에 교환한다.
// 인가 코드는 1회용이라 StrictMode 의 effect 2회 실행으로 재사용되면 두 번째 교환이 실패한다 → ref 로 가드
const useSocialCallback = () => {
    const { provider } = useParams<{ provider: string }>();
    const navigate = useNavigate();
    const { handleSocialLogin } = useAuth();

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
        startTransition(() => dispatchSocialLogin({ provider, code, redirectUri: KAKAO_REDIRECT_URI }));
    }, []);

    return socialLoginState;
};
export default useSocialCallback;
