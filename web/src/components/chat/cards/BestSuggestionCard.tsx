import { Link } from "react-router";
import clsx from "clsx";
import LevelChip from "./LevelChip";
import { buildKakaoMapSearchUrl, formatDateLabel } from "./utils/crowdVisual";
import { useRepresentativeImage } from "./hooks/useRepresentativeImage";

type BestSuggestionCardNeedProps = {
    payload: AreaOverviewData;
};

// 혼잡도 그래프(지역 현황) → 가장 추천 → 대안 순서의 가운데 카드.
// 지역 현황의 samples.quiet 는 집중률 오름차순(명세)이라 첫 항목이 그 지역에서 지금 가장 한적한 곳이다
const BestSuggestionCard = ({ payload } : BestSuggestionCardNeedProps) => {
    const top = payload.samples?.quiet[0];
    const heroImage = useRepresentativeImage(top?.content_id, top?.image);
    if (!top) return null;

    const region = payload.signgu_nm;
    const mapKeyword = region ? `${region} ${top.name}` : top.name;

    return <div className={CardStyle}>
        <div className={CardHeader}>
            <p className={Eyebrow}>가장 추천하는 여행지</p>
            <h4 className={Title}>{region} {formatDateLabel(payload.date)} 가장 한적한 곳</h4>
        </div>

        {/* 대표 이미지 — 응답 image, 없으면 이미지 목록 API 첫 장. 둘 다 없으면 영역을 그리지 않는다 */}
        {heroImage && (
            <img src={heroImage} alt={`${top.name} 대표 이미지`} loading="lazy" className={HeroImage} />
        )}

        <div className={Body}>
            <div className={NameRow}>
                {/* 명세: content_id 가 없으면 이름으로 검색해 상세에 진입 — 아직 검색 진입 화면이 없어 이름만 표시한다 */}
                {top.content_id ? (
                    <Link to={`/attractions/${top.content_id}`} className={clsx(Name, NameLink)}>{top.name}</Link>
                ) : (
                    <p className={Name}>{top.name}</p>
                )}
                <LevelChip level="한적" rate={top.rate} prefix={formatDateLabel(payload.date)} />
            </div>
            <p className={Muted}>이 지역 한적한 관광지 중 집중률이 가장 낮아요</p>
        </div>

        <div className={ActionRow}>
            {top.content_id && <Link to={`/attractions/${top.content_id}`} className={ActionButton}>자세히 보기</Link>}
            <a
                href={buildKakaoMapSearchUrl(mapKeyword)}
                target="_blank"
                rel="noopener noreferrer"
                aria-label={`${top.name} 카카오맵에서 보기 (새 창)`}
                className={ActionButton}
            >
                지도에서 보기 ↗
            </a>
        </div>
    </div>
};
export default BestSuggestionCard;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지역 현황 카드와 같은 톤으로 시작
const CardStyle = clsx(
    "bg-[#333743]",
    "flex flex-col gap-[30px]",
    "rounded-[12px]",
    "p-[22px_32px] box-border",
    "text-[14px] font-normal"
);

const CardHeader = clsx(
    "flex flex-col gap-1"
);

const Eyebrow = clsx(
    "text-[12px] text-[#A3F1F9] font-medium"
);

const Title = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const HeroImage = clsx(
    "w-full h-[180px]",
    "rounded-[12px] object-cover",
    "bg-[#20232C]"
);

const Body = clsx(
    "flex flex-col gap-1 min-w-0"
);

const NameRow = clsx(
    "flex flex-wrap items-center gap-2"
);

const Name = clsx(
    "text-[17px] text-[#FFFFFF] font-semibold"
);

const NameLink = clsx(
    "hover:underline"
);

const Muted = clsx(
    "text-[12px] text-[#6b6375]"
);

const ActionRow = clsx(
    "flex flex-wrap gap-2"
);

const ActionButton = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-3 py-1.5",
    "text-[12px] text-[#FFFFFF] font-normal",
    "hover:bg-[#1A1C22]",
    "hover:border-[#FFFFFF]"
);
