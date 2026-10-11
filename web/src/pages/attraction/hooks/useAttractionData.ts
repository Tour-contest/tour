import { useEffect, useState } from "react";
import { useTour } from "@/hooks/api";
import { todayKey } from "@/components/chat/cards/utils/crowdVisual";

// 카드 그래프는 한 주를 그리고 나머지는 표로 열리므로 두 주치를 받아 표에도 내용이 있게 한다
const CONGESTION_DAYS = 14;
const ALTERNATIVES_LIMIT = 3;
const SIMILAR_LIMIT = 5;
const INTEREST_WEEKS = 4;

// undefined 는 아직 응답 전, null 은 실패 — 화면은 전자에만 "확인 중" 을 보여준다
type Pending<T> = T | null | undefined;

export type AttractionData = {
    detail: Pending<TouristDetailData>;
    images: Pending<TouristImagesData>;
    congestion: Pending<TouristCongestionData>;
    alternatives: Pending<AlternativesTouristData>;
    similar: Pending<SearchSimilarTouristData>;
    pet: Pending<PetAttractionData>;
    interest: Pending<SearchInterestData>;
};

const INITIAL_DATA: AttractionData = {
    detail: undefined,
    images: undefined,
    congestion: undefined,
    alternatives: undefined,
    similar: undefined,
    pet: undefined,
    interest: undefined,
};

// 어느 관광지의 자료인지 함께 들고 있어, 다른 관광지로 옮겨간 뒤 늦게 도착한 응답이 새 화면을 덮어쓰지 않는다.
// 관광지가 바뀌면 effect 에서 초기화하지 않고 읽는 쪽에서 빈 상태로 취급한다 (effect 안의 동기 setState 회피)
type OwnedAttractionData = AttractionData & {
    contentId: string | undefined;
};

// 상세를 먼저 받고, 성공했을 때만 나머지를 부른다 — 혼잡도·대안·유사는 상류 할당량을 쓰므로 없는 관광지에 낭비하지 않는다.
// 부가 정보는 도착하는 대로 각자 반영되어 화면이 위에서부터 채워진다
const useAttractionData = (contentId: string | undefined): AttractionData => {
    const {
        fetchTouristDetail,
        fetchTouristImages,
        fetchTouristCongestion,
        fetchAlternativesTourist,
        fetchSimilarTourists,
        fetchPetAttraction,
        fetchSearchInterest,
    } = useTour();

    const [owned, setOwned] = useState<OwnedAttractionData>({ contentId: undefined, ...INITIAL_DATA });

    useEffect(() => {
        if (!contentId) return;
        // 다른 관광지로 옮겨간 뒤 늦게 도착한 상세 응답이 새 화면을 덮어쓰지 않게 한다.
        // 부가 정보는 patch 가 id 를 비교하지만 상세는 통째로 세팅하므로 이 플래그가 필요하다
        let isCurrent = true;

        const patch = (update: Partial<AttractionData>) => {
            setOwned((prev) => (prev.contentId === contentId ? { ...prev, ...update } : prev));
        };

        fetchTouristDetail(contentId).then((detail) => {
            if (!isCurrent) return;
            setOwned({ contentId, ...INITIAL_DATA, detail });
            if (!detail) return;

            const today = todayKey();
            fetchTouristImages(contentId).then((images) => patch({ images }));
            fetchTouristCongestion(contentId, { days: CONGESTION_DAYS, date_from: today }).then((congestion) => patch({ congestion }));
            fetchAlternativesTourist(contentId, { date: today, limit: ALTERNATIVES_LIMIT }).then((alternatives) => patch({ alternatives }));
            fetchSimilarTourists(contentId, SIMILAR_LIMIT).then((similar) => patch({ similar }));
            fetchPetAttraction(contentId).then((pet) => patch({ pet }));
            fetchSearchInterest(contentId, INTEREST_WEEKS).then((interest) => patch({ interest }));
        });

        return () => { isCurrent = false; };
    }, [contentId]);

    return owned.contentId === contentId ? owned : INITIAL_DATA;
};
export default useAttractionData;
