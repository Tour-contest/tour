//react
import { useState } from "react";
//router
import { useNavigate } from "react-router";
//hooks
import { useChat } from "@/hooks/api";
import useAsyncData from "@/hooks/useAsyncData";
//components
import { LoadingIndicator, Modal } from "@/components/common";
//style
import clsx from "clsx";

type ChatSessionsModalNeedProps = {
    isOpen: boolean;
    onClose: () => void;
};

// 한 페이지 개수 (명세 1~100). 팝업이라 스크롤 없이 한눈에 보이는 정도로
const PAGE_SIZE = 10;
// 번호 버튼은 현재 페이지 앞뒤로 이만큼만 보인다
const PAGE_WINDOW = 2;

// "9/18 14:02". 최근 활동순이라 연도까지는 필요 없다. 원문은 title 툴팁에
const formatDateTime = (iso: string | null) => {
    if (!iso) return "-";
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return iso;
    return `${date.getMonth() + 1}/${date.getDate()} ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
};

// 보여줄 페이지 번호 목록 (현재 ±PAGE_WINDOW, 항상 첫·끝 포함)
const buildPageNumbers = (current: number, pageCount: number): number[] => {
    const numbers = new Set<number>([0, pageCount - 1]);
    for (let page = current - PAGE_WINDOW; page <= current + PAGE_WINDOW; page += 1) {
        if (page >= 0 && page < pageCount) numbers.add(page);
    }
    return [...numbers].sort((a, b) => a - b);
};

// 전체 대화 목록 팝업. 사이드바 스토어와 분리해 페이지 단위로 따로 받는다 (스토어는 "더 보기" 누적용)
const ChatSessionsModal = ({ isOpen, onClose } : ChatSessionsModalNeedProps) => {
    const navigate = useNavigate();
    const { fetchChatSessions } = useChat();

    const [page, setPage] = useState<number>(0);

    // 열려 있을 때만, 페이지가 바뀌면 다시 받는다. 늦게 온 이전 응답은 버린다
    const { data, isLoading, hasError, reload } = useAsyncData(
        page,
        () => fetchChatSessions({ limit: PAGE_SIZE, offset: page * PAGE_SIZE }),
        { isEnabled: isOpen },
    );

    // 닫을 때 첫 페이지로 되돌려 다음에 열면 최근 대화부터 보이게 한다
    const handleClose = () => {
        setPage(0);
        onClose();
    };

    const handleOpenSession = (sessionId: string) => {
        navigate(`/c/${sessionId}`);
        handleClose();
    };

    const sessions = data?.items ?? [];
    const total = data?.page.total ?? 0;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));
    const pageNumbers = buildPageNumbers(page, pageCount);

    return <Modal isOpen={isOpen} title="전체 대화" size="md" hasCloseButton onClose={handleClose}>
        {isLoading && (
            <div className={CenterNote}>
                <LoadingIndicator label="대화 목록을 불러오는 중…" />
            </div>
        )}

        {hasError && (
            <div className={CenterNote}>
                <p className={ErrorText}>대화 목록을 불러오지 못했어요.</p>
                <button type="button" onClick={reload} className={Button}>다시 시도</button>
            </div>
        )}

        {!isLoading && !hasError && sessions.length === 0 && (
            <p className={clsx(CenterNote, Muted)}>아직 대화가 없어요</p>
        )}

        {!isLoading && !hasError && sessions.length > 0 && (
            <>
                <ul className={List}>
                    {
                        sessions.map((session) => {
                            return <li key={session.id}>
                                <button type="button" onClick={() => handleOpenSession(session.id)} className={Row}>
                                    <span className={RowTitle}>{session.title ?? "새 대화"}</span>
                                    <span className={RowMeta}>
                                        <span>메시지 {session.messages}</span>
                                        <span title={session.last_active_at ?? undefined}>{formatDateTime(session.last_active_at)}</span>
                                    </span>
                                </button>
                            </li>
                        })
                    }
                </ul>

                <nav aria-label="대화 목록 페이지" className={Pagination}>
                    <p className={Muted}>전체 {total.toLocaleString()}개</p>
                    <div className={PageButtons}>
                        <button type="button" disabled={page === 0} onClick={() => setPage(page - 1)} className={Button}>이전</button>
                        {
                            pageNumbers.map((number, index) => {
                                const hasGap = index > 0 && number - pageNumbers[index - 1] > 1;
                                return <span key={number} className={PageSlot}>
                                    {hasGap && <span aria-hidden="true" className={Muted}>…</span>}
                                    <button
                                        type="button"
                                        aria-current={number === page ? "page" : undefined}
                                        onClick={() => setPage(number)}
                                        className={clsx(Button, number === page && PageButtonActive)}
                                    >
                                        {number + 1}
                                    </button>
                                </span>
                            })
                        }
                        <button type="button" disabled={page >= pageCount - 1} onClick={() => setPage(page + 1)} className={Button}>다음</button>
                    </div>
                </nav>
            </>
        )}
    </Modal>
}
export default ChatSessionsModal;
//style configuration
// TODO: 디테일 단계에서 개발자와 함께 스타일 작업 예정 — 지금은 구조만
const CenterNote = clsx(
    "flex flex-col items-center justify-center gap-2",
    "py-8"
);

const Muted = clsx(
    "text-[12px] text-[#6b6375]"
);

const ErrorText = clsx(
    "text-[13px] text-[#ff3b30]"
);

const List = clsx(
    "flex flex-col",
    "divide-y divide-[#e5e4e7]"
);

const Row = clsx(
    "flex w-full items-center justify-between gap-3",
    "px-2 py-2",
    "text-left",
    "rounded-[8px]",
    "hover:bg-[#f4f3ec]"
);

const RowTitle = clsx(
    "min-w-0 truncate",
    "text-[14px]"
);

const RowMeta = clsx(
    "flex shrink-0 items-center gap-3",
    "text-[12px] text-[#6b6375] tabular-nums"
);

const Pagination = clsx(
    "flex items-center justify-between gap-3"
);

const PageButtons = clsx(
    "flex items-center gap-1"
);

const PageSlot = clsx(
    "flex items-center gap-1"
);

const Button = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "px-2.5 py-1",
    "text-[12px]",
    "hover:bg-[#f4f3ec]",
    "disabled:opacity-50"
);

const PageButtonActive = clsx(
    "bg-[#1d1c1a] text-white border-[#1d1c1a]",
    "hover:bg-[#1d1c1a]"
);
