declare global {
    type GetUserParams = {
        q?: string;        // 닉네임 · 로그인 ID 부분 일치
        limit?: number;    // 1~200, 기본 50
        offset?: number;   // 기본 0. 검색어를 바꾸면 0 으로 되돌린다
    };

    // 내 정보 조회 — 로그인 응답의 user 와 같은 필드에 가입 시각만 더 붙는다
    type MyInfo = UserInfo & {
        created_at: string | null;
    };

    type ResponseMyInfo = ResponseSuccessData<MyInfo>;

    // 사용자 목록 (관리자)
    type AdminUser = {
        id: string;
        provider: "kakao" | "local" | "dev";
        provider_uid: string | null;   // 카카오 연결 해제에 사용
        login_id: string | null;       // 관리자 계정에만 존재
        nickname: string | null;       // 화면은 nickname → login_id → id 순으로 표시
        role: UserRole;
        status: UserStatus;            // suspended 이면 이후 요청이 403
        fail_count: number | null;
        locked_until: string | null;   // 잠긴 계정에만 존재
        created_at: string | null;
        last_login_at: string | null;
    };

    type AdminUserListData = {
        items: AdminUser[];
        page: OffsetPage;
    };

    type ResponseUserList = ResponseSuccessData<AdminUserListData>;
}
