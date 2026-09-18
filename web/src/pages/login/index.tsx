//react
import { useState } from "react";
//logins
import LoginCard from "@/pages/login/LoginCard";
//style
import clsx from "clsx";
//icons
import MainIcon from "@/assets/logo/main_logo.svg?react";

function Login() {
    const [isAdminMode, setIsAdminMode] = useState<boolean>(false);

    return (
        <div className={LoginContainer}>
            <div className={ContextGroup}>
                <h2 className={Slogan}>
                    내가 방문하고 싶은 곳의 상황이 궁금하다면?<br />
                    <strong className={MainText}>널널 </strong>에게 물어보세요
                </h2>
                {
                    isAdminMode ? null : <div className={BalloonGroup}>
                        <span className={Balloon}>
                            언제쯤 사람들이 제일 많을까?
                        </span>
                        <span className={Balloon}>
                            지금 이 지역 내에서 한산한 관광지 명소는 어디일까?
                        </span>
                        <span className={Balloon}>
                            근처에 같이 들르면 좋은 곳이 있을까?
                        </span>
                    </div>
                }
            </div>
            <MainIcon className="w-[115.259px] h-[104.901px]" aria-label="널널" />
            <LoginCard isAdminMode={isAdminMode} />
            <div className={BottomContext}>
                <p className={Attribution}>출처: ⓒ한국관광공사</p>
                <button className={ModeToggle} type="button" onClick={() => setIsAdminMode((prev) => !prev)}>
                    <div className={ToggleLayout} style={{ justifyContent: isAdminMode ? "end" : "start" }}>
                        <div className={ToggleStatus}></div>
                    </div>
                    {isAdminMode ? "소셜 로그인으로 돌아가기" : "관리자 로그인"}
                </button>
            </div>
        </div>
    );
}
export default Login;
//style configuration
const LoginContainer = clsx(
    "h-screen bg-[#20232C]",
    "bg-[radial-gradient(60%_40%_at_50%_-8%,#A3F1F999_0%,#6FC1FC99_19%,#309AE699_30%,transparent_80%)]",
    "flex flex-col items-center justify-center gap-7.5",
);

const Slogan = clsx(
    "text-center text-[36px] tracking-[0.8px] leading-16.5 font-normal",
    "text-transparent bg-clip-text bg-linear-to-r from-0% from-[#A3F1F9] via-39.9% via-[#6FC1FC] to-100% to-[#309AE6]"
);

const MainText = clsx(
    "text-[40px] text-[#FFFFFF] font-normal",
    "text-shadow-[0px_4px_8.7px_rgba(255_255_255_/0.41)] leading-16.5"
);

const ContextGroup = clsx(
    "flex flex-col gap-11.75 items-center"
);

const BalloonGroup = clsx(
    "w-137.5",
    "flex flex-col gap-7 items-start", 
    "[&>*:nth-child(even)]:self-end",
    "[&>*:nth-child(even)]:rounded-br-none", 
    "[&>*:nth-child(odd)]:rounded-bl-none"
);

const Balloon = clsx(
    "relative bg-[#1A1C22]",
    "border border-[#D8D8D8] rounded-full",
    "p-[15px_32px] box-border",
    "text-[18px] text-[#D8D8D8] font-normal whitespace-nowrap",
);

const BottomContext = clsx(
    "flex gap-5 justify-between items-center"
);

const Attribution = clsx(
    "text-[12px] text-[#949494] font-normal"
);

const ModeToggle = clsx(
    "flex gap-2 items-center",
    "text-[12px] text-[#949494] font-normal underline underline-offset-2",
    "select-none",
    "cursor-pointer"
);

const ToggleLayout = clsx(
    "w-8",
    "flex items-center",
    "border border-[#A3F1F9] rounded-full",
    "p-0.5 box-border",
);

const ToggleStatus = clsx(
    "w-2.5 h-2.5 bg-[#A3F1F9]",
    "rounded-full"
);