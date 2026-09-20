//react
import { useState } from "react";
//router
import { useNavigate } from "react-router";
//hooks
import { useChat } from "@/hooks/api";
import useAsyncData from "@/hooks/useAsyncData";
//components
import { LoadingIndicator, Modal, Pagination } from "@/components/common";
//style
import clsx from "clsx";

type ChatSessionsModalNeedProps = {
    isOpen: boolean;
    onClose: () => void;
};

// 한 페이지 개수 (명세 1~100). 팝업이라 스크롤 없이 한눈에 보이는 정도로
const PAGE_SIZE = 10;
// "9/18 14:02". 최근 활동순이라 연도까지는 필요 없다. 원문은 title 툴팁에
const formatDateTime = (iso: string | null) => {
    if (!iso) return "-";
    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return iso;
    return `${date.getMonth() + 1}/${date.getDate()} ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
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

                <div className={Footer}>
                    <p className={Muted}>전체 {total.toLocaleString()}개</p>
                    {/* 한 페이지면 페이지네이션을 두지 않는다 (Pagination 이 알아서 숨긴다) */}
                    <Pagination page={page} pageCount={pageCount} onChange={setPage} label="대화 목록 페이지" />
                </div>
            </>
        )}
    </Modal>
}
export default ChatSessionsModal;
//style configuration
const CenterNote = clsx(
    "flex flex-col items-center justify-center gap-2",
    "py-8"
);

const Muted = clsx(
    "text-[12px] text-[#909090]"
);

const ErrorText = clsx(
    "text-[13px] text-[#FF7A7A]"
);

const List = clsx(
    "flex flex-col",
    "divide-y divide-[#3A3D47]"
);

const Row = clsx(
    "flex w-full items-center justify-between gap-3",
    "px-3 py-2.5",
    "text-left",
    "rounded-[8px]",
    "cursor-pointer",
    "hover:bg-[#1A1C22]"
);

const RowTitle = clsx(
    "min-w-0 truncate",
    "text-[14px] text-[#FFFFFF]"
);

const RowMeta = clsx(
    "flex shrink-0 items-center gap-3",
    "text-[12px] text-[#909090] tabular-nums"
);

const Footer = clsx(
    "flex items-center justify-between gap-3"
);

const Button = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-2.5 py-1",
    "text-[12px] text-[#FFFFFF]",
    "cursor-pointer",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]",
    "disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:border-[#63717A]"
);

