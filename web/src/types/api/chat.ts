declare global {
    // 대화 세션 목록
    type RequestChatSessionsParams = {
        limit?: number;
        offset?: number;
    };

    type ChatSession = {
        id: string;
        title: string | null;   // null 이면 화면에 "새 대화"로 표시한다
        messages: number;
        last_active_at: string | null;
    };

    type ChatSessionsData = {
        items: ChatSession[];
        page: OffsetPage;
    };

    type ResponseChatSessions = ResponseSuccessData<ChatSessionsData>;

    // 카드 payload — 명세상 각 도구의 REST 응답과 동일하다
    type ChatAttractionListItem = {
        content_id: string;
        title: string;
        addr1?: string;
        image?: string;
        mapx?: number;
        mapy?: number;
        signgu_cd?: string;
        period?: string;   // list_festivals
        note?: string;     // find_pet_friendly
    };

    type ChatAttractionListPayload = {
        status: "ok" | "no_data";
        signgu_nm?: string;
        items: ChatAttractionListItem[];
        confident?: boolean;   // find_attraction
        category?: string;     // list_places
        source?: string;
    };

    type ChatCrowdAttractionItem = {
        content_id: string;
        name: string;
        matched_title?: string;
        match_method?: "exact" | "keyword" | "reverse";
        series: TouristCongestionSeries[];
        summary?: TouristCongestionSummary;
        available_days?: number;
    };

    // 관광지를 지정한 혼잡도 카드. 지역 전체 형태(AreaOverviewData)는 payload 에 summary 가 있다
    type ChatCrowdAttractionPayload = {
        status: "ok" | "no_data";
        signgu_cd?: string;
        signgu_nm?: string;
        items: ChatCrowdAttractionItem[];
        unmatched?: string[];
        source?: string;
    };

    type ChatCard =
        | { type: "attraction_list"; payload: ChatAttractionListPayload }
        | { type: "crowd"; payload: ChatCrowdAttractionPayload | AreaOverviewData }
        | { type: "alternatives"; payload: AlternativesTouristData }
        | { type: "interest"; payload: SearchInterestData }
        | { type: "detail"; payload: TouristDetailData }
        | { type: "visitors"; payload: AreaVisitorsData }
        | { type: "area_overview"; payload: AreaOverviewData }
        | { type: "attraction"; payload: TouristDetailData };

    type ChatCardType = ChatCard["type"];

    // 대화 이력 조회 — 이력만 before 커서를 사용한다
    type RequestChatMessagesParams = {
        limit?: number;
        before?: number;
    };

    type ChatMessage = {
        id: number;
        session_id: string;
        role: "user" | "assistant";
        content: string;
        tool_trace: ChatCard[];   // 과거 카드 복원용. user 메시지는 빈 배열
        created_at: string | null;
    };

    type ChatMessagesData = {
        items: ChatMessage[];
        page: CursorPage;
    };

    type ResponseChatMessages = ResponseSuccessData<ChatMessagesData>;

    // 대화 스트리밍 (SSE) — 공통 응답 형식을 따르지 않는다
    type RequestChatStream = {
        message: string;            // 1~500자
        session_id?: string | null; // 서버 발급 12자리 hex. 생략하면 신규 세션
    };

    type ChatStreamStage =
        | "optimizing"
        | "resolving"
        | "searching"
        | "crowd"
        | "alternatives"
        | "overview"
        | "composing";

    type ChatStreamErrorCode =
        | "LLM_RATE_LIMITED"
        | "LLM_QUOTA_EXHAUSTED"
        | "LLM_ERROR"
        | "INTERNAL_ERROR"
        | "FORBIDDEN"
        | "CHAT_BUSY";

    // meta → (status | tool | card)* → delta* → [sources] → final → done / 실패 시 error 로 종료
    type ChatStreamEvent =
        | { event: "meta"; data: { session_id: string; message_id: string; title: string | null } }
        | { event: "status"; data: { stage: ChatStreamStage; label: string } }
        | { event: "tool"; data: { name: string; status: "ok" | "no_data" | "quota_exceeded" | "upstream_error"; repeated: boolean } }
        | { event: "card"; data: ChatCard }
        | { event: "delta"; data: { text: string } }
        | { event: "sources"; data: { items: { name: string }[]; note: string } }
        | { event: "final"; data: { text: string; unknown_numbers: string[] } }
        | { event: "done"; data: { message_id: string; cards: number } }
        | { event: "error"; data: { code: ChatStreamErrorCode; message: string; retriable: boolean } };
};
