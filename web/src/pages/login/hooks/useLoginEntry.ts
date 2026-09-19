import { useEffect, useState } from "react";
import { clearSession } from "@/api/tokenManager";
import { useAuth } from "@/hooks/api";

// 로그인 화면 진입 = 새 로그인의 시작점.
// 남아있는 세션을 먼저 비우고(만료된 토큰으로 불필요한 refresh 가 돌지 않게 provider 조회보다 앞서) 로그인 수단을 받는다
const useLoginEntry = () => {
    const { fetchAuthenticateProvider } = useAuth();
    const [providerData, setProviderData] = useState<ResponseProviderData | null>(null);

    useEffect(() => {
        clearSession();

        let isCurrent = true;
        fetchAuthenticateProvider().then((data) => {
            if (isCurrent) setProviderData(data);
        });
        return () => { isCurrent = false; };
    }, []);

    return { providerData };
};
export default useLoginEntry;
