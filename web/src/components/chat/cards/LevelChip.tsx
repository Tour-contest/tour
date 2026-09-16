import clsx from "clsx";
import { LevelDotBase, LevelFill, formatRate } from "./crowdVisual";

type LevelChipNeedProps = {
    level: CrowdLevel;
    rate: number;
    prefix?: string;
};

// 색 점이 등급을, 글자가 뜻과 수치를 전한다 — 색만으로 읽게 하지 않는다
const LevelChip = ({ level, rate, prefix } : LevelChipNeedProps) => {
    return <span className={Chip}>
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
    "border border-[#e5e4e7] rounded-full",
    "bg-white",
    "px-2 py-0.5",
    "text-[12px]"
);

const ChipMuted = clsx(
    "text-[#6b6375]"
);

const ChipValue = clsx(
    "font-semibold"
);
