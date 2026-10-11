//style
import clsx from "clsx";
//logo
import MainLogo from "@/assets/logo/main_logo.svg?react";

type AnimatedLogoNeedProps = {
    // 로고 폭(px). 뒤의 빛은 이 크기에 비례한다
    size?: number;
    // 뒤에서 번지는 빛. 작은 크기(생각 중 표시)에서는 끄는 편이 깔끔하다
    hasGlow?: boolean;
    className?: string;
};

// 살아 있는 메인 로고: 떠오르기(float) · 뒤의 빛(glow) · 구름 숨쉬기 · 눈 깜빡임 · 입 웃음(logo-live, index.css).
// 새 채팅 인사 · 답변 생성 중 · 페이지 첫 로딩에서 같은 움직임을 쓴다. 동작 줄이기 설정에서는 전부 멈춘다
const AnimatedLogo = ({ size = 88, hasGlow = true, className } : AnimatedLogoNeedProps) => {
    return <span className={clsx(Frame, className)} style={{ width: size }}>
        {hasGlow && <span aria-hidden="true" className={Glow} />}
        <MainLogo className={Logo} aria-hidden="true" />
    </span>
}
export default AnimatedLogo;
//style configuration
const Frame = clsx(
    "relative inline-flex shrink-0 items-center justify-center",
    "animate-float motion-reduce:animate-none"
);

const Glow = clsx(
    "absolute inset-[10%] rounded-full",
    "bg-[#6FC1FC]",
    "blur-xl",
    "animate-glow motion-reduce:animate-none motion-reduce:opacity-20"
);

const Logo = clsx(
    "logo-live",
    "relative w-full h-auto"
);
