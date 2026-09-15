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

// 자동 재연결은 하지 않는다 — 같은 대화가 중복 처리되면 상류 호출과 모델 비용이 2배가 된다.
// 끊긴 답변은 재전송이 아니라 이어받기(GET /chat/sessions/{id}/stream)로 붙는다
export const openChatStream = async (body: RequestChatStream, { onEvent, signal }: ChatStreamOptions) => {
    const accessToken = await resolveAccessToken();
    if (!accessToken) throw new Error("세션이 만료되었습니다. 다시 로그인해주세요.");

    const response = await fetch(CHAT_STREAM_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(body),
        signal,
    });

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
