import { useState } from "react";
import clsx from "clsx";
import { LoadingIndicator } from "@/components/common";
import { useAreaStore } from "@/store/area";
import { replaceQuestionRegion } from "@/utils";
import DownIcon from "@/assets/icons/down_icon.svg?react";

type ChatbotRegionRetryNeedProps = {
    originalMessage: string;
    isDisabled: boolean;
    onResend: (message: string) => void;
};

type RegionPicker = {
    isOpen: boolean;
    sidoName: string;
    signguName: string;
};

const INITIAL_REGION_PICKER: RegionPicker = {
    isOpen: false,
    sidoName: "",
    signguName: "",
};

// "송암사"처럼 여러 지역에 있는 이름을 모델이 이전 대화의 다른 지역으로 추측할 때,
// 사용자가 지역을 직접 골라 질문 앞에 붙여 다시 보낸다. 서버 동작과 무관하게 항상 쓸 수 있는 교정 수단
const ChatbotRegionRetry = ({ originalMessage, isDisabled, onResend } : ChatbotRegionRetryNeedProps) => {
    const sidoGroups = useAreaStore((state) => state.sidoGroups);
    const loadAreas = useAreaStore((state) => state.loadAreas);

    const [regionPicker, setRegionPicker] = useState<RegionPicker>(INITIAL_REGION_PICKER);

    const signguOptions = sidoGroups.find((group) => group.sido_nm === regionPicker.sidoName)?.items ?? [];

    const handleOpen = () => {
        setRegionPicker((prev) => ({ ...prev, isOpen: true }));
        loadAreas();
    };

    // 시도를 바꾸면 이전 시도의 시군구가 남지 않게 비운다
    const handleSidoChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
        setRegionPicker((prev) => ({ ...prev, sidoName: e.target.value, signguName: "" }));
    };

    const handleSignguChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
        setRegionPicker((prev) => ({ ...prev, signguName: e.target.value }));
    };

    const handleResend = () => {
        if (!regionPicker.sidoName) return;

        const region = regionPicker.signguName
            ? `${regionPicker.sidoName} ${regionPicker.signguName}`
            : regionPicker.sidoName;

        onResend(replaceQuestionRegion(originalMessage, region, sidoGroups));
        setRegionPicker(INITIAL_REGION_PICKER);
    };

    if (!regionPicker.isOpen) {
        return <button type="button" onClick={handleOpen} disabled={isDisabled} className={RetryToggle}>
            지역 지정해서 다시 묻기
        </button>
    }

    return <div className={PickerGroup}>
        {sidoGroups.length === 0 ? (
            <LoadingIndicator label="지역 목록을 불러오는 중…" />
        ) : (
            <>
                {/* 브라우저 기본 화살표 대신 우리 아이콘 — 호출 이력 · 회원 관리 필터와 같은 방식 */}
                <span className={SelectWrap}>
                    <select aria-label="시도 선택" value={regionPicker.sidoName} onChange={handleSidoChange} className={RegionSelect}>
                        <option value="">시도 선택</option>
                        {
                            sidoGroups.map((group) => {
                                return <option key={group.sido_nm} value={group.sido_nm}>{group.sido_nm}</option>
                            })
                        }
                    </select>
                    <DownIcon aria-hidden="true" className={SelectArrow} />
                </span>
                <span className={SelectWrap}>
                    <select
                        aria-label="시군구 선택"
                        value={regionPicker.signguName}
                        onChange={handleSignguChange}
                        disabled={!regionPicker.sidoName}
                        className={RegionSelect}
                    >
                        <option value="">전체</option>
                        {
                            signguOptions.map((area) => {
                                return <option key={area.signgu_cd} value={area.signgu_nm}>{area.signgu_nm}</option>
                            })
                        }
                    </select>
                    <DownIcon aria-hidden="true" className={SelectArrow} />
                </span>
                <button
                    type="button"
                    onClick={handleResend}
                    disabled={isDisabled || !regionPicker.sidoName}
                    className={ResendButton}
                >
                    다시 묻기
                </button>
            </>
        )}
        <button type="button" onClick={() => setRegionPicker(INITIAL_REGION_PICKER)} className={CancelButton}>
            취소
        </button>
    </div>
}
export default ChatbotRegionRetry;
//style configuration
// 답변 말풍선 아래에 붙는 보조 동작 — 어두운 카드 톤에 맞춘다
const RetryToggle = clsx(
    "self-start",
    "text-[13px] text-[#909090] underline underline-offset-2",
    "select-none cursor-pointer",
    "hover:text-[#FFFFFF]",
    "disabled:opacity-50 disabled:cursor-not-allowed"
);

const PickerGroup = clsx(
    "flex flex-wrap items-center gap-2",
    "self-start"
);

const SelectWrap = clsx(
    "relative inline-flex"
);

// 어두운 배경의 셀렉트: 채팅 입력창과 같은 포커스 링. 기본 화살표는 감추고 오른쪽 안쪽 여백을 화살표만큼 넓힌다
const RegionSelect = clsx(
    "appearance-none",
    "border border-[#63717A] rounded-[8px]",
    "bg-[#20232C] text-[#FFFFFF] text-[13px]",
    "pl-3 pr-8 py-1.5",
    "cursor-pointer",
    "outline-none",
    "transition-[border-color,box-shadow] duration-150",
    "focus:border-[#A3F1F9]",
    "focus:shadow-[0_0_0_1.4px_#A3F1F9,0_0_10px_rgba(163,241,249,0.35)]",
    "disabled:opacity-50 disabled:cursor-not-allowed"
);

const SelectArrow = clsx(
    "pointer-events-none",
    "absolute right-3 top-1/2 -translate-y-1/2",
    "w-3 h-2 text-[#909090]"
);

// 확인 모달의 확인 버튼과 같은 강조색 채움
const ResendButton = clsx(
    "rounded-[8px]",
    "bg-[#6FC1FC] text-[#1A1C22]",
    "px-3 py-1.5",
    "text-[13px] font-medium",
    "cursor-pointer",
    "hover:bg-[#A3F1F9]",
    "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-[#6FC1FC]"
);

// 취소는 외곽선만
const CancelButton = clsx(
    "border border-[#63717A] rounded-[8px]",
    "px-3 py-1.5",
    "text-[13px] text-[#FFFFFF]",
    "cursor-pointer",
    "hover:bg-[#1A1C22] hover:border-[#FFFFFF]"
);
