//side features
import { useRepresentativeImage } from "../hooks/useRepresentativeImage";
//style
import clsx from "clsx";

type AttractionThumbnailNeedProps = {
    contentId: string | null | undefined;
    image: string | null | undefined;
    name: string;
};

// 항목 썸네일 (대안 카드 · 관광지 목록 카드 공용).
// 응답 image 가 없으면 이미지 목록 API 첫 장(관광지당 1회, 캐시). 둘 다 없으면 자리만 지키는 빈 상자
const AttractionThumbnail = ({ contentId, image, name } : AttractionThumbnailNeedProps) => {
    const src = useRepresentativeImage(contentId, image);

    if (!src) return <span aria-hidden="true" className={clsx(Thumbnail, ThumbnailEmpty)} />;
    return <img src={src} alt={`${name} 대표 이미지`} loading="lazy" className={Thumbnail} />;
};
export default AttractionThumbnail;
//style configuration
const Thumbnail = clsx(
    "size-14 shrink-0",
    "rounded-[10px] object-cover",
    "bg-[#20232C]"
);

const ThumbnailEmpty = clsx(
    "border border-[#63717A]"
);
