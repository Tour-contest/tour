//style
import clsx from "clsx";
//hooks
import type useResizableWidth from "@/hooks/useResizableWidth";

type SidebarResizeHandleNeedProps = {
    handleProps: ReturnType<typeof useResizableWidth>["handleProps"];
    isResizing: boolean;
};

// 사이드바 오른쪽 가장자리의 끌기 손잡이. 평소엔 안 보이고, 올리면 얇은 선이 뜬다. 더블클릭은 기본 너비로
const SidebarResizeHandle = ({ handleProps, isResizing } : SidebarResizeHandleNeedProps) => {
    return <div
        {...handleProps}
        role="separator"
        aria-orientation="vertical"
        aria-label="사이드바 너비 조절"
        title="끌어서 너비 조절 · 더블클릭으로 기본 너비"
        className={clsx(Handle, isResizing && HandleActive)}
    >
        <span aria-hidden="true" className={clsx(HandleLine, isResizing && HandleLineActive)} />
    </div>
}
export default SidebarResizeHandle;
//style configuration
// 잡기 쉽게 6px 폭을 가장자리 바깥으로 반쯤 걸친다. 실제 보이는 선은 안의 2px
const Handle = clsx(
    "group absolute top-0 -right-[3px] z-10",
    "h-full w-[6px]",
    "flex justify-center",
    "cursor-col-resize select-none",
    "outline-none touch-none"
);

const HandleActive = clsx(
    "cursor-col-resize"
);

const HandleLine = clsx(
    "h-full w-[2px]",
    "bg-transparent",
    "transition-colors",
    "group-hover:bg-[#3A3D47] group-focus-visible:bg-[#6FC1FC]"
);

const HandleLineActive = clsx(
    "bg-[#6FC1FC]"
);
