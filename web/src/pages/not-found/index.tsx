import { Link } from "react-router";
import clsx from "clsx";

function NotFound() {
    return (
        <div className={clsx("flex", "h-full", "flex-col", "items-center", "justify-center", "gap-[12px]")}>
            <p>페이지를 찾을 수 없습니다</p>
            <Link to="/" className={clsx("text-[13px]", "underline")}>
                홈으로
            </Link>
        </div>
    );
}
export default NotFound;
