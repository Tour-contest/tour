import { Outlet } from "react-router";
import clsx from "clsx";
import Sidebar from "./Sidebar";

// 로그인 이후 화면의 통합 레이아웃. 알림 소켓처럼 "로그인 이후에만" 살아야 하는 것도 여기서 마운트한다
function MainLayout() {
    return (
        <div className={clsx("flex", "h-[100vh]")}>
            <Sidebar />
            <main className={clsx("flex-1", "min-w-0")}>
                <Outlet />
            </main>
        </div>
    );
}
export default MainLayout;
