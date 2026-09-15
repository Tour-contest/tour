declare global {
    type ResponseSuccessData<TData> = {
        success: boolean;
        code: "OK";
        message?: string | null;
        retriable: boolean;
        timestamp: string;
        data: TData;
    };

    // 등급은 이 3개 단어만 사용한다 (공통 명세 "화면 표기 규칙")
    type CrowdLevel = "혼잡" | "보통" | "한적";

    // 처리성 API 공통 응답 — 로그아웃 / 세션 삭제 / 사용자 상태 변경 / 회원 탈퇴
    type ProcessResult = {
        ok: boolean;
    };

    type ResponseProcess = ResponseSuccessData<ProcessResult>;

    // 목록 페이징 — offset 방식
    type OffsetPage = {
        limit: number;
        offset: number;
        total: number;
        has_more: boolean;
    };

    // 목록 페이징 — before 커서 방식 (대화 이력 전용). 중간에 메시지가 늘어도 페이지가 밀리지 않는다
    type CursorPage = {
        limit: number;
        has_more: boolean;
        next_before: number | null;
    };
};