import { useState } from "react";
import clsx from "clsx";
// 카드 썸네일과 같은 아이콘. 파일 고유색(#333743)을 그대로 쓴다 — 색을 주려면 text-* 와 [&_path]:fill-current 를 붙인다
import ExcludeIcon from "@/assets/logo/exclude.svg?react";

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
    // 불러오기에 실패한 주소들 (서버가 준 링크가 깨져 있을 수 있다). 같은 주소는 다시 시도하지 않는다
    const [failedUrls, setFailedUrls] = useState<string[]>([]);

    const items = images?.status === "ok" ? images.items : [];
    const selected = items[selectedIndex] ?? items[0];
    const heroUrl = selected?.url || representativeImage || "";
    const isHeroBroken = heroUrl !== "" && failedUrls.includes(heroUrl);

    const markFailed = (url: string) => {
        setFailedUrls((prev) => (prev.includes(url) ? prev : [...prev, url]));
    };

    // 주소가 아예 없으면 갤러리 없이 안내만
    if (!heroUrl) {
        return <div className={EmptyHero}>
            <ExcludeIcon aria-hidden="true" className={EmptyIcon} />
            <p className={EmptyText}>이미지가 없어요</p>
        </div>
    }

    return <div className={GalleryGroup}>
        {/* 큰 사진이 깨지면 같은 자리에 안내를 둔다 — 썸네일 줄은 그대로라 다른 사진을 고를 수 있다 */}
        {isHeroBroken ? (
            <div className={EmptyHero}>
                <ExcludeIcon aria-hidden="true" className={EmptyIcon} />
                <p className={EmptyText}>이미지를 불러오지 못했어요</p>
            </div>
        ) : (
            <figure className={HeroFrame}>
                <img src={heroUrl} alt={selected?.name || title} loading="eager" onError={() => markFailed(heroUrl)} className={HeroImage} />
                {selected?.copyright && <figcaption className={Copyright}>ⓒ {selected.copyright}</figcaption>}
            </figure>
        )}

        {items.length > 1 && (
            <ul className={ThumbnailRow} aria-label={`${title} 사진 ${items.length}장`}>
                {
                    items.map((image, index) => {
                        const isSelected = index === selectedIndex;
                        const thumbnailUrl = image.small || image.url;
                        const isThumbnailBroken = failedUrls.includes(thumbnailUrl);

                        return <li key={image.url}>
                            <button
                                type="button"
                                aria-label={image.name || `${index + 1}번째 사진`}
                                aria-pressed={isSelected}
                                onClick={() => setSelectedIndex(index)}
                                className={clsx(ThumbnailButton, isSelected && ThumbnailSelected)}
                            >
                                {isThumbnailBroken ? (
                                    <span className={ThumbnailEmpty}>
                                        <ExcludeIcon aria-hidden="true" className={ThumbnailEmptyIcon} />
                                    </span>
                                ) : (
                                    <img src={thumbnailUrl} alt="" loading="lazy" onError={() => markFailed(thumbnailUrl)} className={ThumbnailImage} />
                                )}
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

// 사진이 없거나 못 불러왔을 때: 카드 썸네일과 같은 회색 구름 아이콘 + 안내 한 줄
const EmptyHero = clsx(
    "flex flex-col items-center justify-center gap-2",
    "aspect-[16/9] w-full",
    "rounded-[12px]",
    "border border-[#63717A]",
    "bg-[#1A1C22]"
);

const EmptyIcon = clsx(
    "w-10 h-10"
);

// 아이콘 아래 안내 문구 — 큰 자리라 카드 각주보다 한 단계 크게
const EmptyText = clsx(
    "text-[14px] text-[#909090]"
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

const ThumbnailEmpty = clsx(
    "flex size-full items-center justify-center",
    "bg-[#20232C]"
);

const ThumbnailEmptyIcon = clsx(
    "w-6 h-6"
);
