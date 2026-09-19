import { useEffect, useState } from "react";
import { getTouristImages } from "@/service/tour";

// 이미지 목록 조회는 상류(TourAPI) 호출이라 할당량을 쓴다. 같은 관광지는 페이지당 한 번만 부르고 결과를 나눠 쓴다
const imageCache = new Map<string, Promise<string | null>>();

export const loadRepresentativeImage = (contentId: string) => {
    const cached = imageCache.get(contentId);
    if (cached) return cached;

    const request = getTouristImages(contentId)
        .then((res) => res.data.items[0]?.url ?? null)
        .catch((e) => {
            console.error(e);
            // 실패한 건 캐시에서 빼서 다음 카드가 다시 시도할 수 있게 한다
            imageCache.delete(contentId);
            return null;
        });

    imageCache.set(contentId, request);
    return request;
};

// 응답에 image 가 없으면(명세 Nullable, 실제로 빈 문자열이 흔함) 이미지 목록 API 의 첫 장을 대표 이미지로 쓴다.
// 응답 image 가 있으면 호출하지 않는다
export const useRepresentativeImage = (contentId: string | null | undefined, image: string | null | undefined) => {
    const [fetchedImage, setFetchedImage] = useState<string | null>(null);

    useEffect(() => {
        if (image || !contentId) return;

        let isCurrent = true;
        loadRepresentativeImage(contentId).then((url) => {
            if (isCurrent) setFetchedImage(url);
        });
        return () => { isCurrent = false; };
    }, [contentId, image]);

    return image || fetchedImage;
};
