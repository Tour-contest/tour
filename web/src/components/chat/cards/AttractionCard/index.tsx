//router
import { Link } from "react-router";
//side components
import AttractionThumbnail from "./AttractionThumbnail";
//side features
import { buildKakaoMapSearchUrl } from "../utils/crowdVisual";
//style
import clsx from "clsx";
//icons
import MapIcon from "@/assets/logo/map_icon.svg?react";

type AttractionCardNeedProps = {
    contentId: string;
    title: string | null | undefined;
    image?: string | null;
    // 주소 · 행사 기간 · 반려동물 안내처럼 항목마다 다른 한 줄 부가 정보
    note?: string | null;
    // 지도 검색어 앞에 붙일 지역명 (같은 이름의 관광지가 여러 지역에 있어 지역을 함께 검색한다)
    region?: string | null;
};

// 관광지 목록(attraction_list) · 단일 관광지(detail/attraction) 카드의 항목 행.
// 대안 카드의 항목과 같은 배치(썸네일 · 이름 · 부가 정보 · 지도)이되, 집중률 정보는 이 응답에 없어 등급 칩 대신 "자세히 보기"를 둔다
const AttractionCard = ({ contentId, title, image, note, region } : AttractionCardNeedProps) => {
    const name = title || "이름 없는 관광지";
    const mapKeyword = region ? `${region} ${name}` : name;

    return <div className={ItemRow}>
        <AttractionThumbnail contentId={contentId} image={image} name={name} />
        <div className={ItemMain}>
            <Link to={`/attractions/${contentId}`} className={ItemName}>{name}</Link>
            {note && <p className={Muted}>{note}</p>}
        </div>
        <div className={ActionGroup}>
            <Link to={`/attractions/${contentId}`} className={ActionLink}>자세히 보기</Link>
            <a
                href={buildKakaoMapSearchUrl(mapKeyword)}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${name} 카카오맵에서 보기 (새 창)`}
                className={ActionLink}
            >
                <MapIcon />
                <p>지도 ↗</p>
            </a>
        </div>
    </div>
};
export default AttractionCard;
//style configuration
// AlternativesCard 의 항목 행과 같은 값
const ItemRow = clsx(
    "flex items-center justify-between gap-3",
    "border-b border-[#63717A] last:border-b-0",
    "py-2.5"
);

const ItemMain = clsx(
    "flex flex-1 flex-col gap-1 min-w-0"
);

const ItemName = clsx(
    "truncate",
    "text-[14px] text-[#FFFFFF] font-semibold",
    "hover:underline"
);

const Muted = clsx(
    "truncate",
    "text-[12px] text-[#909090]"
);

const ActionGroup = clsx(
    "flex items-center gap-2 shrink-0"
);

const ActionLink = clsx(
    "flex items-center gap-1 shrink-0",
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1",
    "text-[14px] text-[#FFFFFF] font-normal",
    "hover:bg-[#1A1C22]",
    "hover:border-[#FFFFFF]"
);
