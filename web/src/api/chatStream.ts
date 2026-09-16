import { isTokenExpired, requestRefresh, applyRefreshedToken, clearSession } from "./tokenManager";
import { useAuthenticateStore } from "@/store/authenticate";
import type { ErrorResponse } from "@/types/error";

const CHAT_STREAM_URL = "/api/v1/chat/stream";

// axios 인터셉터를 타지 않는 경로라 Bearer 준비를 여기서 직접 한다 (선제 만료 검사 포함)
const resolveAccessToken = async () => {
    const accessToken = useAuthenticateStore.getState().accessToken;
    if (!accessToken) return null;
    if (!isTokenExpired(accessToken)) return accessToken;

    try {
        const res = await requestRefresh();

        if (res.success) {
            applyRefreshedToken(res.data);
            return res.data.access_token;
        }
    } catch (e) {
        console.error(e);
    }

    clearSession();
    return null;
};

// 네트워크 경계라 파싱 결과는 단언할 수밖에 없다. 형태가 어긋나면 이벤트 하나를 버린다
const parseStreamEvent = (frame: string): ChatStreamEvent | null => {
    let eventName = "";
    const dataLines: string[] = [];

    for (const rawLine of frame.split("\n")) {
        const line = rawLine.replace(/\r$/, "");

        if (line.startsWith(":")) continue;
        if (line.startsWith("event:")) eventName = line.slice(6).trim();
        else if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
    }

    if (!eventName || dataLines.length === 0) return null;

    try {
        return { event: eventName, data: JSON.parse(dataLines.join("\n")) } as ChatStreamEvent;
    } catch (e) {
        console.error("SSE data 파싱 실패", e);
        return null;
    }
};

type ChatStreamOptions = {
    onEvent: (streamEvent: ChatStreamEvent) => void;
    signal?: AbortSignal;
};

const requireAccessToken = async () => {
    const accessToken = await resolveAccessToken();
    if (!accessToken) throw new Error("세션이 만료되었습니다. 다시 로그인해주세요.");
    return accessToken;
};

// 전송과 이어받기는 이벤트 형식이 같아 소비 로직을 공유한다
const consumeEventStream = async (response: Response, onEvent: ChatStreamOptions["onEvent"]) => {
    // 스트림이 시작되기 전의 오류는 공통 응답 형식으로 내려온다
    if (!response.ok || !response.body) {
        const errorResponse = (await response.json().catch(() => null)) as ErrorResponse | null;
        throw new Error(errorResponse?.message ?? "대화를 시작하지 못했습니다.");
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    for (;;) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer = (buffer + decoder.decode(value, { stream: true })).replace(/\r\n/g, "\n");

        const frames = buffer.split("\n\n");
        buffer = frames.pop() ?? "";

        for (const frame of frames) {
            const streamEvent = parseStreamEvent(frame);
            if (streamEvent) onEvent(streamEvent);
        }
    }
};

// 자동 재연결은 하지 않는다 — 같은 대화가 중복 처리되면 상류 호출과 모델 비용이 2배가 된다.
// 끊긴 답변은 재전송이 아니라 아래 이어받기로 붙는다
export const openChatStream = async (body: RequestChatStream, { onEvent, signal }: ChatStreamOptions) => {
    const accessToken = await requireAccessToken();

    const response = await fetch(CHAT_STREAM_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(body),
        signal,
    });

    await consumeEventStream(response, onEvent);
};

// 새로고침·이탈로 끊긴 답변에 다시 붙는다. 형식은 전송과 같고 meta 가 오지 않는다.
// 지금까지 만든 이벤트를 처음부터 재생한 뒤 실시간으로 잇고, 진행 중인 생성이 없으면 done 하나만 온다.
// 이미 도는 생성을 구독만 하므로 여러 번 붙어도 상류 호출·모델 비용이 늘지 않는다
export const resumeChatStream = async (sessionId: string, { onEvent, signal }: ChatStreamOptions) => {
    const accessToken = await requireAccessToken();

    // GET 이지만 Authorization 헤더가 필요해 EventSource 대신 fetch 를 쓴다
    const response = await fetch(`/api/v1/chat/sessions/${sessionId}/stream`, {
        headers: { Authorization: `Bearer ${accessToken}` },
        signal,
    });

    await consumeEventStream(response, onEvent);
};
