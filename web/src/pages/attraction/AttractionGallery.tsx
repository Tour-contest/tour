import { useState } from "react";
import clsx from "clsx";

type AttractionGalleryNeedProps = {
    title: string;
    // 상세 응답의 대표 이미지. 갤러리가 오기 전에도 먼저 보인다
    representativeImage: string | null | undefined;
    images: TouristImagesData | null;
};

// 대표 이미지 1장(상세 응답)과 이미지 목록(/images)을 한 갤러리로 합친다.
// 목록에는 원본·썸네일·저작권이 함께 오므로 큰 화면은 url, 줄은 small 로 그리고 저작권 문구를 붙인다
const AttractionGallery = ({ title, representativeImage, images } : AttractionGalleryNeedProps) => {
    const [selectedIndex, setSelectedIndex] = useState<number>(0);

    const items = images?.status === "ok" ? images.items : [];
    const selected = items[selectedIndex] ?? items[0];
    const heroUrl = selected?.url || representativeImage || "";

    if (!heroUrl) {
        return <div className={EmptyHero}>
            <p className={Muted}>등록된 사진이 없어요</p>
        </div>
    }

    return <div className={GalleryGroup}>
        <figure className={HeroFrame}>
            <img src={heroUrl} alt={selected?.name || title} loading="eager" className={HeroImage} />
            {selected?.copyright && <figcaption className={Copyright}>ⓒ {selected.copyright}</figcaption>}
        </figure>

        {items.length > 1 && (
            <ul className={ThumbnailRow} aria-label={`${title} 사진 ${items.length}장`}>
                {
                    items.map((image, index) => {
                        const isSelected = index === selectedIndex;

                        return <li key={image.url}>
                            <button
                                type="button"
                                aria-label={image.name || `${index + 1}번째 사진`}
                                aria-pressed={isSelected}
                                onClick={() => setSelectedIndex(index)}
                                className={clsx(ThumbnailButton, isSelected && ThumbnailSelected)}
                            >
                                <img src={image.small || image.url} alt="" loading="lazy" className={ThumbnailImage} />
                            </button>
                        </li>
                    })
                }
            </ul>
        )}
    </div>
}
export default AttractionGallery;
//style configuration
const GalleryGroup = clsx(
    "flex flex-col gap-2"
);

// 어두운 배경 위 갤러리. 사진이 뜨기 전에는 카드보다 한 톤 어두운 바탕이 자리를 지킨다
const HeroFrame = clsx(
    "relative m-0",
    "aspect-[16/9] w-full max-w-full",
    "overflow-hidden rounded-[12px]",
    "bg-[#1A1C22]"
);

const HeroImage = clsx(
    "size-full object-cover"
);

const Copyright = clsx(
    "absolute bottom-0 right-0",
    "rounded-tl-[8px]",
    "bg-[#1A1C22]/80 text-[#D8D8D8]",
    "px-2 py-1",
    "text-[11px]"
);

const EmptyHero = clsx(
    "flex items-center justify-center",
    "aspect-[16/9] w-full",
    "rounded-[12px]",
    "bg-[#333743]"
);

// 가로 썸네일 줄도 얇은 스크롤바 (세로 스크롤러와 같은 규칙)
const ThumbnailRow = clsx(
    "flex gap-2",
    "overflow-x-auto",
    "pb-1",
    "scrollbar-thin-hover",
);

const ThumbnailButton = clsx(
    "block size-16 shrink-0",
    "overflow-hidden rounded-[8px]",
    "border-2 border-transparent",
    "opacity-60 hover:opacity-100",
    "cursor-pointer"
);

// 선택된 사진은 포커스 링과 같은 하늘색
const ThumbnailSelected = clsx(
    "border-[#A3F1F9] opacity-100"
);

const ThumbnailImage = clsx(
    "size-full object-cover"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);
