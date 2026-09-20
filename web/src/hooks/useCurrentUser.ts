import { useEffect } from "react";
import { getMyInfo } from "@/service/user";
import { useAuthenticateStore } from "@/store/authenticate";

// 유저 정보는 브라우저 저장소에 두지 않는다 (토큰만 sessionStorage). 로그인 응답으로 메모리에 실리고,
// 새로고침으로 비면 내 정보 API 로 한 번 채운다. 사이드바 · 인사말이 같이 쓰므로 요청은 하나만 나가게 공유한다
let pendingRequest: Promise<void> | null = null;

const loadCurrentUser = () => {
    if (pendingRequest) return pendingRequest;

    pendingRequest = getMyInfo()
        .then((res) => {
            // 기다리는 사이 로그아웃했거나(토큰 없음) 다른 계정으로 로그인했다면(유저가 이미 실림) 늦게 온 응답을 버린다.
            // 토큰 값 자체는 갱신으로 바뀔 수 있어 비교하지 않는다
            const { accessToken, user, setUser } = useAuthenticateStore.getState();
            if (!res.success || !accessToken || user) return;

            setUser(res.data);
        })
        .catch((e) => {
            console.error(e);
        })
        .finally(() => {
            pendingRequest = null;
        });

    return pendingRequest;
};

const useCurrentUser = () => {
    const user = useAuthenticateStore((state) => state.user);
    const accessToken = useAuthenticateStore((state) => state.accessToken);

    useEffect(() => {
        if (user || !accessToken) return;
        loadCurrentUser();
    }, [user, accessToken]);

    return user;
};
export default useCurrentUser;
