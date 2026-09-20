import { create } from "zustand";
import { getAreas } from "@/service/area";

// 시군구 목록은 서버 DB 조회라 상류 할당량을 쓰지 않고 값도 거의 바뀌지 않는다 — 한 번 받아 재사용한다 (명세: 클라이언트 캐싱 권장)
type AreaState = {
    sidoGroups: SidoGroup[];
    loadAreas: () => Promise<void>;
};

// 여러 곳에서 동시에 열어도 요청은 한 번만 나가도록 진행 중인 요청을 공유한다
let loadingPromise: Promise<void> | null = null;

export const useAreaStore = create<AreaState>((set, get) => ({
    sidoGroups: [],
    loadAreas: () => {
        if (get().sidoGroups.length > 0) return Promise.resolve();

        if (!loadingPromise) {
            loadingPromise = getAreas()
                .then((res) => set({ sidoGroups: res.data.sido }))
                .catch((e) => console.error(e))
                .finally(() => { loadingPromise = null; });
        }
        return loadingPromise;
    },
}));
