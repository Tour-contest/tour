import { create } from "zustand";
import { getReady } from "@/service/system";

// 서버가 지금 제공할 수 있는 기능 (GET /readyz). 인증이 필요 없고 사용자와 무관한 값이라
// 페이지 로드당 한 번만 받아 두고 첫 화면의 안내 판단에 쓴다
type SystemState = {
    ready: ReadyData | null;
    loadReady: () => Promise<void>;
};

let readyPromise: Promise<void> | null = null;

export const useSystemStore = create<SystemState>((set, get) => ({
    ready: null,

    // 여러 화면이 동시에 불러도 요청은 한 번 (single-flight). 실패하면 안내를 띄우지 않을 뿐이라 조용히 넘어간다
    loadReady: () => {
        if (get().ready) return Promise.resolve();
        if (!readyPromise) {
            readyPromise = getReady()
                .then((res) => { set({ ready: res.data }); })
                .catch((e) => { console.error(e); })
                .finally(() => { readyPromise = null; });
        }
        return readyPromise;
    },
}));
