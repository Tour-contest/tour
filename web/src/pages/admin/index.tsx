import { useEffect, useState } from "react";
import clsx from "clsx";
import { useUser } from "@/hooks/api";

// TODO: 관제 대시보드(SB-06) 화면으로 교체 — 현재는 Authorization 헤더 부착 확인용
function Admin() {
    const { fetchUsers } = useUser();

    const [probeMessage, setProbeMessage] = useState<string>("회원 목록 조회 중…");

    useEffect(() => {
        fetchUsers().then((res) => {
            setProbeMessage(res ? "회원 목록 조회 성공 (응답은 콘솔)" : "회원 목록 조회 실패 (콘솔 확인)");
        });
    }, []);

    return (
        <div className={clsx("flex", "h-full", "flex-col", "items-center", "justify-center", "gap-[8px]")}>
            <p>관제 대시보드</p>
            <p className={clsx("text-[13px]", "text-[#6b6375]")}>{probeMessage}</p>
        </div>
    );
}
export default Admin;
