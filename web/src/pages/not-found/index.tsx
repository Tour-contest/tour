//router
import { useNavigate } from "react-router";
//style
import clsx from "clsx";
//icons
import ErrorIcon from '@/assets/logo/error.svg?react';

type NotFoundNeedProps = {
    code?: string;
    title?: string;
    // 줄마다 <p> 로 그린다
    descriptions?: string[];
    actionLabel?: string;
    // 기본 동작(홈으로) 대신 부를 동작
    onAction?: () => void;
};

// 라우터의 "*" (없는 주소) 화면이자, 상세 페이지처럼 "찾지 못했어요" 상태를 같은 모양으로 보여줄 때도 쓴다
const NotFound = ({
    code = "404",
    title = "길을 잃어버렸어요",
    descriptions = ["주소가 바뀌었거나 삭제된 페이지일 수 있어요.", "주소를 한 번 더 확인해 주세요."],
    actionLabel = "홈으로 이동하기",
    onAction,
} : NotFoundNeedProps) => {
    const navigate = useNavigate();

    // 어디서 왔든 홈으로. 관리자는 권한 가드가 /admin 으로 다시 보낸다
    const handleGoHome = () => navigate("/");

    return <div className={Page}>
        <div className="flex flex-col items-center gap-20">
            <ErrorIcon className="w-57.5 h-52.5"/>
            <div className={TextGroup}>
                <p className={Code}>{code}</p>
                <div className="flex flex-col items-center gap-2.5">
                    <h1 className={Title}>{title}</h1>
                    <div>
                        {
                            descriptions.map((line) => {
                                return <p key={line} className={Description}>{line}</p>
                            })
                        }
                    </div>
                </div>
            </div>
        </div>
        <button type="button" onClick={onAction ?? handleGoHome} className={HomeButton}>{actionLabel}</button>
    </div>
}
export default NotFound;
//style configuration
const Page = clsx(
    "flex h-screen flex-col items-center justify-center gap-8.75",
    "bg-[#20232C]",
    "p-6",
    "animate-fade-in motion-reduce:animate-none"
);

const TextGroup = clsx(
    "flex flex-col items-center gap-3.5",
    "text-center"
);

const Code = clsx(
    "text-[50px] text-[#309AE6] font-normal leading-none tabular-nums"
);

const Title = clsx(
    "text-[30px] text-[#FFFFFF] font-medium"
);

const Description = clsx(
    "text-[16px] text-[#C6C6C6] font-normal"
);

// 확인 모달의 확인 버튼과 같은 강조색 채움
const HomeButton = clsx(
    "rounded-full",
    "bg-[#309AE6] text-[#FFFFFF]",
    "p-[6px_20px] box-border",
    "text-[15px] font-normal",
    "cursor-pointer",
    "hover:bg-[#6FC1FC]"
);
