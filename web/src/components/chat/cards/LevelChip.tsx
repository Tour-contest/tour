import clsx from "clsx";
import { LevelDotBase, LevelFill, formatRate } from "./utils/crowdVisual";

type LevelChipNeedProps = {
    level: CrowdLevel;
    rate: number;
    prefix?: string;
};

const BADGE_BORDER_COLOR: Record<CrowdLevel, string> = {
    한적: "border-[#15B836]",
    보통: "border-[#D3A418]",
    혼잡: "border-[#B84B15]",
};

const LABEL_COLOR: Record<CrowdLevel, string> = {
    한적: "text-[#15B836]",
    보통: "text-[#D3A418]",
    혼잡: "text-[#B84B15]",
};

// 색 점이 등급을, 글자가 뜻과 수치를 전한다 — 색만으로 읽게 하지 않는다
const LevelChip = ({ level, rate, prefix } : LevelChipNeedProps) => {
    return <span className={clsx(BADGE_BORDER_COLOR[level], LABEL_COLOR[level] ,Chip)}>
        <span aria-hidden="true" className={clsx(LevelDotBase, LevelFill[level])} />
        {prefix && <span className={ChipMuted}>{prefix}</span>}
        <span>{level}</span>
        <span className={ChipValue}>{formatRate(rate)}</span>
    </span>
}
export default LevelChip;
//style configuration
const Chip = clsx(
    "inline-flex items-center gap-1 shrink-0",
    "border rounded-full",
    "px-2 py-0.5",
    "text-[14px] font-normal"
);

const ChipMuted = clsx(
    // "text-[#6b6375]",
    'text-[14px] font-normal'
);

const ChipValue = clsx(
    "font-semibold"
);
