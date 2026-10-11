//style
import clsx from "clsx";
//components
import AnimatedLogo from "./AnimatedLogo";

type LogoLoadingNeedProps = {
    label: string;
};

// 페이지 단위 대기 화면(스플래시 성격): 살아 있는 로고 + 안내 문구.
// 버튼 안 · 목록 한 줄 같은 작은 자리는 LoadingIndicator(스피너)를 그대로 쓴다
const LogoLoading = ({ label } : LogoLoadingNeedProps) => {
    return <div role="status" className={Layout}>
        <AnimatedLogo size={72} />
        <p className={Label}>{label}</p>
    </div>
}
export default LogoLoading;
//style configuration
const Layout = clsx(
    "flex flex-col items-center justify-center gap-5",
    "h-full w-full",
    "animate-fade-in motion-reduce:animate-none"
);

const Label = clsx(
    "text-[14px] text-[#D8D8D8] font-normal"
);
