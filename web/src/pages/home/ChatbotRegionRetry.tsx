import { useState } from "react";
import clsx from "clsx";
import { useAreaStore } from "@/store/area";
import { replaceQuestionRegion } from "@/utils";

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
            <p className={MutedMessage}>지역 목록을 불러오는 중이에요</p>
        ) : (
            <>
                <select aria-label="시도 선택" value={regionPicker.sidoName} onChange={handleSidoChange} className={RegionSelect}>
                    <option value="">시도 선택</option>
                    {
                        sidoGroups.map((group) => {
                            return <option key={group.sido_nm} value={group.sido_nm}>{group.sido_nm}</option>
                        })
                    }
                </select>
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
const RetryToggle = clsx(
    "self-start",
    "text-[12px] text-[#6b6375] underline underline-offset-2",
    "select-none",
    "disabled:opacity-50"
);

const PickerGroup = clsx(
    "flex flex-wrap items-center gap-2",
    "self-start"
);

const MutedMessage = clsx(
    "text-[12px] text-[#6b6375]"
);

const RegionSelect = clsx(
    "border border-[#b1bdc8] rounded-[8px]",
    "px-2 py-1",
    "text-[13px]",
    "disabled:opacity-50"
);

const ResendButton = clsx(
    "rounded-[8px]",
    "bg-[#222] text-white",
    "px-3 py-1",
    "text-[13px]",
    "disabled:opacity-50"
);

const CancelButton = clsx(
    "text-[12px] text-[#6b6375]"
);
