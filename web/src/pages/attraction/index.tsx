import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router";
import clsx from "clsx";
import { AlternativesCard, CrowdAttractionCard } from "@/components/chat";
import { LoadingIndicator, LogoLoading } from "@/components/common";
import { buildKakaoMapPointUrl, buildKakaoMapSearchUrl } from "@/components/chat/cards/utils/crowdVisual";
import { decodeHtmlText } from "@/utils";
import AttractionGallery from "./AttractionGallery";
import useAttractionData from "./hooks/useAttractionData";
import { CONTENT_TYPE_LABEL, LCLS1_LABEL, toCrowdPayload } from "./utils/attractionDisplay";

const ATTRIBUTION = "출처: ⓒ한국관광공사";
// 명세: 소개글은 400자까지 표시한다. 그 이상은 접어 두고 펼쳐 볼 수 있게 한다
const OVERVIEW_LIMIT = 400;

type OverviewTextNeedProps = {
    text: string;
};

const OverviewText = ({ text } : OverviewTextNeedProps) => {
    const [isOpen, setIsOpen] = useState<boolean>(false);

    const isLong = text.length > OVERVIEW_LIMIT;
    const visibleText = isOpen || !isLong ? text : `${text.slice(0, OVERVIEW_LIMIT)}…`;

    return <div className={OverviewGroup}>
        <p className={OverviewBody}>{visibleText}</p>
        {isLong && (
            <button type="button" aria-expanded={isOpen} onClick={() => setIsOpen((prev) => !prev)} className={TextToggle}>
                {isOpen ? "접기" : "더 보기"}
            </button>
        )}
    </div>
}

// 대화 카드에서 관광지를 눌러 들어오는 상세. 상세 조회만으로 최근 본 관광지에 기록된다 (명세)
function Attraction() {
    const navigate = useNavigate();
    const { contentId } = useParams<{ contentId: string }>();
    const { detail, images, congestion, alternatives, similar, pet, interest } = useAttractionData(contentId);

    // 대화에서 넘어왔으면 그 대화로, 주소로 바로 열었으면 홈으로 돌아간다
    const handleBackClick = () => {
        if (window.history.state?.idx > 0) navigate(-1);
        else navigate("/");
    };

    if (detail === undefined) {
        return <div className={CenterNote}>
            <LogoLoading label="관광지 정보를 불러오는 중…" />
        </div>
    }

    if (!detail) {
        return <div className={clsx(CenterNote, "flex-col gap-3")}>
            <p>관광지 정보를 찾지 못했어요</p>
            <Link to="/" className={clsx("text-[13px]", "underline")}>홈으로</Link>
        </div>
    }

    const title = detail.title || "이름 없는 관광지";
    const region = [detail.sido_nm, detail.signgu_nm].filter(Boolean).join(" ");
    const typeLabel = detail.content_type_id ? CONTENT_TYPE_LABEL[detail.content_type_id] : undefined;
    const overview = detail.overview ? decodeHtmlText(detail.overview) : "";

    // 명세: 좌표(mapx·mapy)가 있어야 지도 버튼을 낸다. 없으면 이름 검색으로 대신 연다
    const mapUrl = detail.mapx != null && detail.mapy != null
        ? buildKakaoMapPointUrl(title, detail.mapx, detail.mapy)
        : buildKakaoMapSearchUrl(region ? `${region} ${title}` : title);

    const hasAlternatives = alternatives?.status === "ok" && alternatives.items.length > 0;
    const similarItems = similar?.status === "ok" ? similar.items : [];
    const petItems = pet?.status === "ok" ? pet.items : [];
    const interestItems = interest?.status === "ok" ? interest.items.filter((item) => item.trend !== "flat") : [];

    return <div className={PageContainer}>
        <div className={PageLayout}>
            <button type="button" onClick={handleBackClick} className={BackButton}>← 돌아가기</button>

            <div className={Header}>
                <div className={TitleGroup}>
                    <h1 className={Title}>{title}</h1>
                    <p className={Muted}>
                        {[region, typeLabel].filter(Boolean).join(" · ")}
                    </p>
                </div>
                <a
                    href={mapUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label={`${title} 카카오맵에서 보기 (새 창)`}
                    className={ActionButton}
                >
                    지도에서 보기 ↗
                </a>
            </div>

            <AttractionGallery key={contentId} title={title} representativeImage={detail.image} images={images ?? null} />

            {/* 관심도는 카드가 아니라 1행 안내이며 flat 이면 표시하지 않는다 (대화 카드와 같은 규칙) */}
            {
                interestItems.map((item) => {
                    return <p key={item.name} className={Muted}>
                        {item.display_name} 검색 관심도 {item.trend === "rising" ? "상승" : "하락"} {item.change_pct}% (최근 {item.weeks}주)
                    </p>
                })
            }

            {(overview || detail.addr1 || detail.tel) && (
                <section className={Section}>
                    {overview && <OverviewText key={contentId} text={overview} />}
                    {detail.addr1 && <p className={ContactRow}><span className={Muted}>주소</span>{detail.addr1}</p>}
                    {detail.tel && <p className={ContactRow}><span className={Muted}>문의</span>{detail.tel}</p>}
                </section>
            )}

            {congestion === undefined && <LoadingIndicator label="혼잡도를 확인하는 중…" />}
            {congestion && congestion.has_data && (
                <div className={FadeIn}>
                    <CrowdAttractionCard payload={toCrowdPayload(title, congestion)} isTitleLink={false} />
                </div>
            )}
            {congestion && !congestion.has_data && (
                <section className={Section}>
                    <p className={SectionTitle}>혼잡도</p>
                    <p className={Muted}>{congestion.message || "이 관광지는 집중률 자료가 없어요"}</p>
                </section>
            )}

            {hasAlternatives && (
                <div className={FadeIn}>
                    <AlternativesCard payload={alternatives} />
                </div>
            )}

            {/* 명세: info 가 비어 있으면 카드를 표시하지 않는다 */}
            {detail.info.length > 0 && (
                <section className={Section}>
                    <p className={SectionTitle}>이용 안내</p>
                    <dl className={InfoList}>
                        {
                            // 같은 항목명이 두 번 올 수도 있어 순서를 붙여 유일하게 만든다
                            detail.info.map((item, index) => {
                                return <div key={`${item.label}-${index}`} className={InfoRow}>
                                    <dt className={InfoName}>{item.label}</dt>
                                    <dd className={InfoValue}>{decodeHtmlText(item.value)}</dd>
                                </div>
                            })
                        }
                    </dl>
                </section>
            )}

            {petItems.length > 0 && (
                <section className={Section}>
                    <p className={SectionTitle}>반려동물 동반</p>
                    <dl className={InfoList}>
                        {
                            petItems.map((item, index) => {
                                return <div key={`${item.label}-${index}`} className={InfoRow}>
                                    <dt className={InfoName}>{item.label}</dt>
                                    <dd className={InfoValue}>{decodeHtmlText(item.value)}</dd>
                                </div>
                            })
                        }
                    </dl>
                    {pet?.source && <p className={Muted}>{pet.source}</p>}
                </section>
            )}

            {similarItems.length > 0 && (
                <section className={Section}>
                    <p className={SectionTitle}>비슷한 관광지</p>
                    <ul className={SimilarList}>
                        {
                            similarItems.map((item) => {
                                return <li key={item.content_id} className={SimilarRow}>
                                    <Link to={`/attractions/${item.content_id}`} className={SimilarLink}>{item.title}</Link>
                                    <span className={Muted}>{LCLS1_LABEL[item.lcls1] ?? item.lcls1}</span>
                                </li>
                            })
                        }
                    </ul>
                    {similar?.source && <p className={Muted}>{similar.source}</p>}
                </section>
            )}

            <p className={Attribution}>{detail.source || ATTRIBUTION}</p>
        </div>
    </div>
}
export default Attraction;
//style configuration
// 챗봇 홈과 같은 구조: 실제 스크롤되는 요소가 본문 전체 폭이라 스크롤바가 오른쪽 끝에 붙고, 내용만 가운데 720px 로 모은다.
// 스크롤바도 같은 규칙 — 얇고, 평소엔 투명, 올리면 배경에 맞춘 회색
const PageContainer = clsx(
    "h-full w-full bg-[#20232C]",
    "overflow-y-auto",
    "[scrollbar-width:thin] [scrollbar-color:transparent_transparent]",
    "hover:[scrollbar-color:#3A3D47_transparent]",
    "[&::-webkit-scrollbar]:w-1.5",
    "[&::-webkit-scrollbar-track]:bg-transparent",
    "[&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-transparent",
    "hover:[&::-webkit-scrollbar-thumb]:bg-[#3A3D47]",
);

const PageLayout = clsx(
    "flex flex-col gap-4",
    "min-h-full w-180 max-w-full mx-auto",
    "p-6 box-border",
    "text-[#FFFFFF]",
    "animate-fade-in motion-reduce:animate-none"
);

// 늦게 도착하는 부가 정보(혼잡도·대안·이용안내 등)는 각자 도착하는 순간 서서히 나타난다
const FadeIn = clsx(
    "animate-fade-in motion-reduce:animate-none"
);

const CenterNote = clsx(
    "flex items-center justify-center",
    "h-full bg-[#20232C]",
    "text-[#FFFFFF]"
);

const BackButton = clsx(
    "self-start",
    "text-[13px] text-[#909090]",
    "hover:text-[#FFFFFF]",
    "select-none cursor-pointer"
);

const Header = clsx(
    "flex items-start justify-between gap-3"
);

const TitleGroup = clsx(
    "flex flex-col gap-1 min-w-0"
);

const Title = clsx(
    "text-[24px] text-[#FFFFFF] font-medium"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);

// 카드 안 버튼과 같은 모양 (대안 카드 · 추천 카드의 ActionButton)
const ActionButton = clsx(
    "shrink-0",
    "border border-[#63717A] rounded-[8px]",
    "px-3 py-1.5",
    "text-[12px] text-[#FFFFFF] font-normal",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]"
);

// 대화 카드와 같은 톤의 어두운 카드
const Section = clsx(
    "flex flex-col gap-3",
    "rounded-[12px]",
    "bg-[#333743]",
    "p-[22px_32px] box-border",
    "text-[14px] font-normal",
    "animate-fade-in motion-reduce:animate-none"
);

const SectionTitle = clsx(
    "text-[20px] text-[#FFFFFF] font-medium"
);

const OverviewGroup = clsx(
    "flex flex-col gap-1"
);

const OverviewBody = clsx(
    "text-[14px] text-[#D8D8D8] leading-relaxed",
    "whitespace-pre-line"
);

const TextToggle = clsx(
    "self-start",
    "text-[12px] text-[#909090] underline underline-offset-2",
    "hover:text-[#FFFFFF]",
    "select-none cursor-pointer"
);

const ContactRow = clsx(
    "flex gap-2",
    "text-[#D8D8D8]"
);

const InfoList = clsx(
    "flex flex-col"
);

const InfoRow = clsx(
    "flex gap-3",
    "border-b border-[#63717A] last:border-b-0",
    "py-2.5"
);

const InfoName = clsx(
    "w-24 shrink-0",
    "text-[#909090]"
);

const InfoValue = clsx(
    "m-0 min-w-0",
    "text-[#D8D8D8]",
    "whitespace-pre-line"
);

const SimilarList = clsx(
    "flex flex-col"
);

const SimilarRow = clsx(
    "flex items-center justify-between gap-3",
    "border-b border-[#63717A] last:border-b-0",
    "py-2.5"
);

const SimilarLink = clsx(
    "truncate",
    "text-[14px] text-[#FFFFFF] font-semibold",
    "hover:underline"
);

const Attribution = clsx(
    "pb-4",
    "text-[12px] text-[#909090]"
);
