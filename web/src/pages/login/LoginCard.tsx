//react
import { useEffect, useState } from "react";
//api
import { clearSession } from "@/api/tokenManager";
//hooks
import { useAuth } from "@/hooks/api";
//logins
import AdminLoginForm from "./AdminLoginForm";
import SocialLogin from "./SocialLogin";
//style
import clsx from "clsx";

type LoginCardNeedProps = {
    isAdminMode: boolean;
};

const LoginCard = ({ isAdminMode } : LoginCardNeedProps) => {
    const [providerData, setProviderData] = useState<ResponseProviderData | null>(null);

    const { fetchAuthenticateProvider } = useAuth();

    useEffect(() => {
        clearSession();
        fetchAuthenticateProvider().then(setProviderData);
    }, []);

    return <div className={LoginCardWrapper}>
        <div className={LoginCardLayout}>
            <h3 className={LoginTitle}>{isAdminMode ? "관리자 로그인" : "지금 바로 널널과 함께 확인해 보세요!"}</h3>
            {isAdminMode ? <AdminLoginForm /> : <SocialLogin providerData={providerData} />}
        </div>
    </div> 
}
export default LoginCard;
//style configuration
const LoginCardWrapper = clsx(
    "flex flex-col items-center gap-3"
);

const LoginCardLayout = clsx(
    "w-117 bg-linear-to-r from-0% from-[#A3F1F913] via-39.9% via-[#6FC1FC13] to-100% to-[#309AE613]",
    "flex flex-col gap-7 justify-center items-center",
    "border-[1.5px] border-[#A3F1F9] rounded-[40px]",
    'p-[38px_0px] box-border',
    'shadow-[5px_4px_8px_rgba(255_255_255_/0.12)]'
);

const LoginTitle = clsx(
    "text-[#FFFFFF] text-[18px] font-normal tracking-[2px]"
);