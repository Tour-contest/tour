import { Navigate, Outlet } from "react-router";
import { useAuthorityStore } from "@/store/authority";

type PrivateAuthorityRouteProps = {
    allow: UserRole[];
};

// 권한별 홈. 허용되지 않은 화면에 들어오면 자기 권한의 홈으로 되돌린다 (SB-01 의 상호 리다이렉트)
const HOME_PATH_BY_ROLE: Record<UserRole, string> = {
    admin: "/admin",
    user: "/",
};

// 2차 가드: PrivateRoute 통과 뒤 권한만 판단한다
const PrivateAuthorityRoute = ({ allow }: PrivateAuthorityRouteProps) => {
    const role = useAuthorityStore((state) => state.role);

    if (!role) return <Navigate to="/login" replace />;
    if (!allow.includes(role)) return <Navigate to={HOME_PATH_BY_ROLE[role]} replace />;

    return <Outlet />;
};
export default PrivateAuthorityRoute;
