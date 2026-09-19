import { Link, Navigate } from "react-router";
import clsx from "clsx";
import { LogoLoading } from "@/components/common";
import useSocialCallback from "./hooks/useSocialCallback";

// 소셜 인가 서버가 돌아오는 착지 라우트 (/oauth/:provider/callback) — code 교환은 훅이, 여기는 결과 표시만
function SocialCallback() {
    const socialLoginState = useSocialCallback();

    // 권한별 최종 목적지는 라우터 가드가 다시 정리한다
    if (socialLoginState.isSuccess) return <Navigate to="/" replace />;

    return (
        <div className={clsx("flex", "h-[100vh]", "flex-col", "items-center", "justify-center", "gap-3", "bg-[#20232C]")}>
            {socialLoginState.errorMessage ? (
                <>
                    <p className={clsx("text-[13px]", "text-[#FF7A7A]")}>{socialLoginState.errorMessage}</p>
                    <Link to="/login" className={clsx("text-[13px]", "text-[#D8D8D8]", "underline", "hover:text-[#FFFFFF]")}>
                        로그인으로 돌아가기
                    </Link>
                </>
            ) : (
                <LogoLoading label="로그인 처리 중…" />
            )}
        </div>
    );
}
export default SocialCallback;
