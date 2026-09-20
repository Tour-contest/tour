import { Navigate, Outlet } from "react-router";
import { useAuthenticateStore } from "@/store/authenticate";

// 1차 가드: 로그인 여부만 판단한다
const PrivateRoute = () => {
    const accessToken = useAuthenticateStore((state) => state.accessToken);

    if (!accessToken) return <Navigate to="/login" replace />;

    return <Outlet />;
};
export default PrivateRoute;
