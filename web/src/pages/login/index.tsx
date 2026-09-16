import { useEffect, useState } from "react";
import clsx from "clsx";
import { clearSession } from "@/api/tokenManager";
import { useAuth } from "@/hooks/api";
import AdminLoginForm from "./AdminLoginForm";
import SocialLogin from "./SocialLogin";

const ATTRIBUTION = "출처: ⓒ한국관광공사";

// 페이지는 진입 수명주기(세션 정리 · 로그인 수단 조회)와 로그인 방식 전환만 맡고, 방식별 처리는 하위로 나눈다
function Login() {
    const { fetchAuthenticateProvider } = useAuth();

    const [providerData, setProviderData] = useState<ResponseProviderData | null>(null);
    // SB-01 — 같은 카드 안에서 소셜 ↔ 관리자 폼을 페이지 이동 없이 전환한다
    const [isAdminMode, setIsAdminMode] = useState<boolean>(false);

    useEffect(() => {
        // 로그인 화면 진입 = 새 로그인의 시작점이므로 남아있는 세션을 먼저 비운다.
        // provider 조회보다 앞서야 만료된 토큰으로 불필요한 refresh 가 돌지 않는다.
        // 자식 effect 는 부모보다 먼저 실행되므로 이 두 작업은 하위 컴포넌트로 옮기면 순서가 뒤집힌다
        clearSession();
        fetchAuthenticateProvider().then(setProviderData);
    }, []);

    return (
        <div className={LoginContainer}>
            <div className={LoginCard}>
                <div className={BrandGroup}>
                    <h1 className={BrandTitle}>
                        널널{isAdminMode && <span className={BrandBadge}>관리자</span>}
                    </h1>
                    {!isAdminMode && <p className={BrandSubtitle}>붐비지 않는 여행의 시작</p>}
                </div>
                {isAdminMode ? <AdminLoginForm /> : <SocialLogin providerData={providerData} />}
            </div>

            {/* 소셜 버튼과 시각적 위계를 분리해 일반 사용자 시선에는 걸리지 않게 둔다. 이동이 아니라 전환이라 링크가 아닌 버튼 */}
            <button type="button" onClick={() => setIsAdminMode((prev) => !prev)} className={ModeToggle}>
                {isAdminMode ? "← 일반 로그인으로 돌아가기" : "관리자 로그인"}
            </button>

            <p className={Attribution}>{ATTRIBUTION}</p>
        </div>
    );
}
export default Login;
//style configuration
const LoginContainer = clsx(
    "flex flex-col items-center justify-center gap-4",
    "h-[100vh]"
);

const LoginCard = clsx(
    "flex flex-col gap-6",
    "w-80",
    "border border-[#e5e4e7] rounded-[12px]",
    "p-6 box-border"
);

const BrandGroup = clsx(
    "flex flex-col items-center gap-1"
);

const BrandTitle = clsx(
    "flex items-center gap-2",
    "text-[24px] font-black"
);

const BrandBadge = clsx(
    "rounded-[6px]",
    "bg-[#222] text-white",
    "px-2 py-0.5",
    "text-[12px] font-bold"
);

const BrandSubtitle = clsx(
    "text-[13px] text-[#6b6375]"
);

const ModeToggle = clsx(
    "text-[12px] text-[#6b6375] underline underline-offset-2",
    "select-none"
);

const Attribution = clsx(
    "text-[12px] text-[#6b6375]"
);
