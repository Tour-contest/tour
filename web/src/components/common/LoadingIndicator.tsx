import clsx from "clsx";

type LoadingIndicatorNeedProps = {
    label: string;
};

// 앱 안의 모든 대기 상태가 같은 모양으로 보이게 하는 스피너 + 안내 문구.
// 서버가 느리면 응답이 올 때까지 그대로 머물고, 내용은 도착하는 순간 페이드인(animate-fade-in)으로 이어진다
const LoadingIndicator = ({ label } : LoadingIndicatorNeedProps) => {
    return <span role="status" className={Indicator}>
        <span aria-hidden="true" className={Spinner} />
        {label}
    </span>
}
export default LoadingIndicator;
//style configuration
const Indicator = clsx(
    "inline-flex items-center gap-2",
    "text-[12px] text-[#909090]"
);

// 위쪽 한 칸만 진하게 남긴 원이 돌아간다. 동작 줄이기 설정에서는 멈춘 원만 보인다
const Spinner = clsx(
    "size-4 shrink-0",
    "rounded-full",
    "border-2 border-[#3A3D47] border-t-[#6FC1FC]",
    "animate-spin motion-reduce:animate-none"
);
