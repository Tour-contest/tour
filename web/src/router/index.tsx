import { useRoutes } from "react-router";
import { PrivateRoute, PrivateAuthorityRoute } from "./private";
import { MainLayout } from "@/layout";
import Login from "@/pages/login";
import SocialCallback from "@/pages/social-callback";
import Home from "@/pages/home";
import Admin from "@/pages/admin";
import AdminUsers from "@/pages/admin-users";
import NotFound from "@/pages/not-found";

const Router = () => {
    return useRoutes([
        { path: "/login", element: <Login /> },
        { path: "/oauth/:provider/callback", element: <SocialCallback /> },
        {
            element: <PrivateRoute />,
            children: [
                {
                    path: "/",
                    element: <MainLayout />,
                    children: [
                        {
                            element: <PrivateAuthorityRoute allow={["user"]} />,
                            children: [
                                { index: true, element: <Home /> },
                                { path: "c/:sessionId", element: <Home /> },
                            ],
                        },
                        {
                            element: <PrivateAuthorityRoute allow={["admin"]} />,
                            children: [
                                { path: "admin", element: <Admin /> },
                                { path: "admin/users", element: <AdminUsers /> },
                            ],
                        },
                        { path: "*", element: <NotFound /> },
                    ],
                },
            ],
        },
    ]);
};
export default Router;
