//router
import { Link } from "react-router";
//side components
import LevelChip from "../LevelChip";
//side features
import { buildCandidateSourceText, buildReasonText } from "./alternativesText";
import { buildKakaoMapSearchUrl } from "../utils/crowdVisual";
import { useRepresentativeImage } from "../hooks/useRepresentativeImage";
//style
import clsx from "clsx";
//icons
import MapIcon from "@/assets/logo/map_icon.svg?react";

type AlternativesCardNeedProps = {
    payload: AlternativesTouristData;
};

type AlternativeThumbnailNeedProps = {
    contentId: string | null | undefined;
    image: string | null | undefined;
    name: string;
};

// 항목 썸네일. 응답 image 가 없으면 이미지 목록 API 첫 장(관광지당 1회, 캐시). 둘 다 없으면 자리만 지키는 빈 상자
const AlternativeThumbnail = ({ contentId, image, name } : AlternativeThumbnailNeedProps) => {
    const src = useRepresentativeImage(contentId, image);

    if (!src) return <span aria-hidden="true" className={clsx(Thumbnail, ThumbnailEmpty)} />;
    return <img src={src} alt={`${name} 대표 이미지`} loading="lazy" className={Thumbnail} />;
};

// SB-03 STEP 3 — 덜 붐비는 대안 추천
const AlternativesCard = ({ payload } : AlternativesCardNeedProps) => {
    // 순서는 서버가 확정한 값이라 재정렬하지 않는다 (명세)
    const items = payload.items;
    const region = payload.signgu_nm;
    const baseName = payload.base?.name;
    const candidateSourceText = buildCandidateSourceText(payload.candidate_source, region);


    return <div className={CardShell}>
        <h4 className={CardTitle}>{baseName ? `${baseName} 대신 여기는 어때요?` : "덜 붐비는 곳을 찾았어요"}</h4>
        <ul className={ItemList}>
            {
                items.map((item) => {
                    const reasonText = buildReasonText(item.reason);
                    const mapKeyword = region ? `${region} ${item.name}` : item.name;

                    return <li key={item.content_id ?? item.name} className={ItemRow}>
                        <AlternativeThumbnail contentId={item.content_id} image={item.image} name={item.name} />
                        <div className={ItemMain}>
                            <div className={ItemTitleRow}>
                                {/* content_id 가 없는 항목은 상세로 이어줄 수 없어 이름만 표시한다 */}
                                {item.content_id ? (
                                    <Link to={`/attractions/${item.content_id}`} className={clsx(ItemName, ItemLink)}>{item.name}</Link>
                                ) : (
                                    <p className={ItemName}>{item.name}</p>
                                )}
                                <LevelChip level={item.level} rate={item.rate} />
                            </div>
                            {reasonText && <p className={Muted}>{reasonText}</p>}
                        </div>
                        <a
                            href={buildKakaoMapSearchUrl(mapKeyword)}
                            target="_blank"
                            rel="noopener noreferrer"
                            aria-label={`${item.name} 카카오맵에서 보기 (새 창)`}
                            className={MapLink}
                        >
                            <MapIcon />
                            <p>지도 ↗</p>
                        </a>
                    </li>
                })
            }
        </ul>

        <div className={FooterNotes}>
            <p className={Muted}>
                {candidateSourceText ? `${candidateSourceText} · ` : ""}집중률은 예측값이에요
            </p>
            {payload.source && <p className={Muted}>{payload.source}</p>}
        </div>
    </div>
}
export default AlternativesCard;
//style configuration
const CardShell = clsx(
    "flex flex-col gap-3",
    "rounded-[12px]",
    "bg-[#333743]",
    "p-[22px_32px] box-border",
    "text-[13px]"
);

const CardTitle = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const ItemList = clsx(
    "flex flex-col",
);

const ItemRow = clsx(
    "flex items-center justify-between gap-3",
    "border-b border-[#63717A] last:border-b-0",
    "py-2.5"
);

const Thumbnail = clsx(
    "size-14 shrink-0",
    "rounded-[10px] object-cover",
    "bg-[#20232C]"
);

const ThumbnailEmpty = clsx(
    "border border-[#63717A]"
);

const ItemMain = clsx(
    "flex flex-1 flex-col gap-1 min-w-0"
);

const ItemTitleRow = clsx(
    "flex flex-wrap items-center gap-2"
);

const ItemName = clsx(
    "text-[14px] text-[#FFFFFF] font-semibold"
);

const ItemLink = clsx(
    "hover:underline"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);

const MapLink = clsx(
    "flex items-center gap-1 shrink-0",
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1",
    "text-[14px] text-[#FFFFFF] font-normal",
    "hover:bg-[#1A1C22]",
    "hover:border-[#FFFFFF]"
);

const FooterNotes = clsx(
    "flex flex-col"
);
