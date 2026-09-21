//style
import clsx from "clsx";

type PaginationNeedProps = {
    // 0 부터 세는 현재 페이지
    page: number;
    pageCount: number;
    onChange: (page: number) => void;
    // nav 의 aria-label (예: "대화 목록 페이지")
    label: string;
};

// 번호 버튼은 현재 페이지를 가운데 둔 3개 + 항상 첫·끝. 사이가 비면 "…" (예: 1 … 4 5 6 … 10)
const PAGE_WINDOW_SIZE = 3;

// 보여줄 페이지 번호 목록. 창(3개)은 현재 페이지가 가운데 오되 양 끝에서는 안쪽으로 밀린다 (1 2 3 … 10 / 1 … 8 9 10)
const buildPageNumbers = (current: number, pageCount: number): number[] => {
    const start = Math.max(0, Math.min(current - Math.floor(PAGE_WINDOW_SIZE / 2), pageCount - PAGE_WINDOW_SIZE));
    const numbers = new Set<number>([0, pageCount - 1]);
    for (let page = start; page < start + PAGE_WINDOW_SIZE; page += 1) {
        if (page >= 0 && page < pageCount) numbers.add(page);
    }
    return [...numbers].sort((a, b) => a - b);
};

// 공용 페이지네이션 (전체 대화 팝업 · 호출 이력). 한 페이지뿐이면 아무것도 그리지 않는다
const Pagination = ({ page, pageCount, onChange, label } : PaginationNeedProps) => {
    if (pageCount <= 1) return null;

    const pageNumbers = buildPageNumbers(page, pageCount);

    return <nav aria-label={label} className={PageButtons}>
        <button type="button" disabled={page === 0} onClick={() => onChange(page - 1)} className={Button}>이전</button>
        {
            pageNumbers.map((number, index) => {
                const hasGap = index > 0 && number - pageNumbers[index - 1] > 1;
                return <span key={number} className={PageSlot}>
                    {hasGap && <span aria-hidden="true" className={Gap}>…</span>}
                    <button
                        type="button"
                        aria-current={number === page ? "page" : undefined}
                        onClick={() => onChange(number)}
                        className={clsx(Button, number === page && PageButtonActive)}
                    >
                        {number + 1}
                    </button>
                </span>
            })
        }
        <button type="button" disabled={page >= pageCount - 1} onClick={() => onChange(page + 1)} className={Button}>다음</button>
    </nav>
}
export default Pagination;
//style configuration
const PageButtons = clsx(
    "flex items-center gap-1"
);

const PageSlot = clsx(
    "flex items-center gap-1"
);

const Gap = clsx(
    "text-[12px] text-[#909090]"
);

const Button = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1",
    "text-[12px] text-[#FFFFFF]",
    "cursor-pointer",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]",
    "disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:border-[#63717A]"
);

// 지금 보는 페이지: 강조색 채움
const PageButtonActive = clsx(
    "bg-[#6FC1FC] text-[#1A1C22] border-[#6FC1FC]",
    "hover:bg-[#6FC1FC] hover:border-[#6FC1FC]"
);
