//react
import { useState } from "react";
//side features
import { useRepresentativeImage } from "../hooks/useRepresentativeImage";
//style
import clsx from "clsx";
//icons
// 단색 아이콘은 icons/ 에 두면 svgr 이 색을 currentColor 로 바꿔 text-* 로 칠할 수 있다
import ExcludeIcon from "@/assets/logo/exclude.svg?react";

type AttractionThumbnailNeedProps = {
    contentId: string | null | undefined;
    image: string | null | undefined;
    name: string;
};

// 항목 썸네일 (대안 카드 · 관광지 목록 카드 공용).
// 응답 image 가 없으면 이미지 목록 API 첫 장(관광지당 1회, 캐시). 둘 다 없거나 주소가 깨져 못 불러오면 자리만 지키는 빈 상자
const AttractionThumbnail = ({ contentId, image, name } : AttractionThumbnailNeedProps) => {
    const src = useRepresentativeImage(contentId, image);
    // 마지막으로 실패한 주소. src 가 바뀌면 다시 시도한다
    const [failedSrc, setFailedSrc] = useState<string | null>(null);

    if (!src || src === failedSrc) return <span aria-hidden="true" className={clsx(Thumbnail, ThumbnailEmpty)}>
        <ExcludeIcon className={EmptyIcon} />
    </span>;
    return <img src={src} alt={`${name} 대표 이미지`} loading="lazy" onError={() => setFailedSrc(src)} className={Thumbnail} />;
};
export default AttractionThumbnail;
//style configuration
const Thumbnail = clsx(
    "size-14 shrink-0",
    "rounded-[10px] object-cover",
    "bg-[#20232C]"
);

// 이미지 없음: 테두리 상자 가운데에 회색 구름 아이콘 (배경 #20232C 위라 카드색으로 칠하면 안 보인다)
const ThumbnailEmpty = clsx(
    "flex items-center justify-center",
    "border border-[#63717A]"
);

const EmptyIcon = clsx(
    "w-9 h-9",
);
