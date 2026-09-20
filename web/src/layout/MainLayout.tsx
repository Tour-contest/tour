import { Outlet } from "react-router";
import Sidebar from "./sideBar";
import clsx from "clsx";

// 로그인 이후 화면의 통합 레이아웃. 알림 소켓처럼 "로그인 이후에만" 살아야 하는 것도 여기서 마운트한다
function MainLayout() {
    return (
        <div className={MainLayoutContainer}>
            {/* 키보드 사용자용: 평소엔 숨겨져 있다가 Tab 으로 포커스되면 나타난다 */}
            <a href="#main-content" className={SkipLink}>본문으로 건너뛰기</a>
            <Sidebar />
            <main id="main-content" tabIndex={-1} className={clsx("flex-1", "min-w-0", "outline-none")}>
                <Outlet />
            </main>
        </div>
    );
}
export default MainLayout;
//style configuration
const SkipLink = clsx(
    "sr-only focus:not-sr-only",
    "focus:fixed focus:left-4 focus:top-4 focus:z-[100]",
    "focus:rounded-[8px] focus:bg-[#6FC1FC] focus:px-4 focus:py-2",
    "focus:text-[14px] focus:text-[#1A1C22] focus:font-medium",
    "focus:outline-none"
);

const MainLayoutContainer = clsx(
    "h-screen bg-[#20232C]",
    "flex"
);
