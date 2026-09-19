import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/demo_script.dart';

/// `docs/API_SPEC.md`의 `### chat` 절에 정의된 SSE 이벤트 하나를 나타낸다.
/// 도착 순서: [ChatMetaEvent](1회) → [ChatStatusEvent](반복) → [ChatToolEvent](반복) →
/// [ChatCardEvent](반복) → [ChatDeltaEvent](반복) → [ChatSourcesEvent](카드 있을 때만) →
/// [ChatFinalEvent](1회) → [ChatDoneEvent](1회) / 실패 시 [ChatErrorEvent].
///
/// 카드가 문장([ChatDeltaEvent])보다 먼저 도착할 수 있으므로 호출부는 도착 순서대로
/// 렌더링해야 하고, 문장 속 수치와 카드 수치가 다르면 카드가 원본이다.
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

/// 스트림당 1회, 최초에 도착한다. 새 대화로 보낸 요청이었다면 이 이벤트의
/// [sessionId]를 이후 메시지에 계속 실어 보내야 한다.
class ChatMetaEvent extends ChatStreamEvent {
  const ChatMetaEvent({required this.sessionId});
  final String sessionId;

  @override
  String toString() => 'ChatMetaEvent(sessionId: $sessionId)';
}

/// 진행 상태 안내. **[실서버로 확인함]** 실제 필드명은 `message`가 아니라
/// `label`(화면에 그대로 노출해도 되는 문구, 예: "질문 이해 중")이고, 기계가
/// 읽는 단계 값 `stage`(예: `optimizing`/`resolving`/`composing`)도 함께 온다.
class ChatStatusEvent extends ChatStreamEvent {
  const ChatStatusEvent({required this.message, this.stage});
  final String message;
  final String? stage;

  @override
  String toString() => 'ChatStatusEvent(message: $message, stage: $stage)';
}

/// 백엔드가 호출한 도구(공공데이터 조회 등)의 진행 상황. 스키마가 아직 확정되지
/// 않아 [name] 외 나머지 필드는 [raw]에 그대로 담아둔다.
class ChatToolEvent extends ChatStreamEvent {
  const ChatToolEvent({required this.name, required this.raw});
  final String name;
  final Map<String, dynamic> raw;

  @override
  String toString() => 'ChatToolEvent(name: $name, raw: $raw)';
}

/// 혼잡도 예보/대안 추천 등 카드 UI로 렌더링할 데이터.
/// [type]/[payload] 필드명 세부 스키마는 아직 명세서에 예시가 없어 그대로 보관한다.
class ChatCardEvent extends ChatStreamEvent {
  const ChatCardEvent({required this.type, required this.payload});
  final String type;
  final Map<String, dynamic> payload;

  /// `payload.status`가 `no_data`이거나 `payload.has_data`가 `false`면 카드 대신
  /// 후속 질문 버튼("지역 전체 현황 보기" 등)을 그려야 한다(`docs/API_SPEC.md`).
  /// `ChatCardBlock.hasData`(`data/demo_script.dart`)와 같은 기준을 공유한다.
  bool get hasData => chatCardPayloadHasData(payload);

  /// [MockChatApi] 전용 지름길. 실제 카드 JSON 스키마가 아직 없어, 데모 목업은
  /// 화면이 바로 렌더링할 수 있는 원본 [AiBlock](`ForecastBlock` 등)을 이 키에
  /// 그대로 실어 보낸다. 실제 [DioChatApi] 응답에는 없는 필드라 항상 `null`이며,
  /// 그 경우 호출부가 `type`/`payload`의 나머지 필드로 직접 파싱해야 한다.
  AiBlock? get demoBlock => payload['demoBlock'] as AiBlock?;

  @override
  String toString() {
    // 로그가 지저분해지지 않도록 demoBlock(MockChatApi 전용 지름길)은 제외한다.
    final loggablePayload = Map<String, dynamic>.from(payload)
      ..remove('demoBlock');
    return 'ChatCardEvent(type: $type, hasData: $hasData, payload: $loggablePayload)';
  }
}

/// AI 답변 문장 조각. 이어붙이면 전체 문장이 된다.
class ChatDeltaEvent extends ChatStreamEvent {
  const ChatDeltaEvent({required this.text});
  final String text;

  @override
  String toString() => 'ChatDeltaEvent(text: "$text")';
}

/// 카드가 있을 때만, [ChatFinalEvent] 직전에 도착하는 출처 목록.
class ChatSourcesEvent extends ChatStreamEvent {
  const ChatSourcesEvent({required this.sources});
  final List<Map<String, dynamic>> sources;

  @override
  String toString() => 'ChatSourcesEvent(count: ${sources.length})';
}

/// 스트림당 1회, 답변 본문이 모두 도착했음을 알린다.
class ChatFinalEvent extends ChatStreamEvent {
  const ChatFinalEvent();

  @override
  String toString() => 'ChatFinalEvent()';
}

/// 스트림당 1회, 연결을 마무리해도 된다는 신호.
class ChatDoneEvent extends ChatStreamEvent {
  const ChatDoneEvent();

  @override
  String toString() => 'ChatDoneEvent()';
}

/// 스트림 처리 중 실패. **자동 재연결 금지** — 재시도는 사용자가 버튼으로만 하도록
/// 호출부에서 이 이벤트(혹은 스트림 자체의 에러)를 받아 안내만 하고 끝내야 한다.
/// **[API 문서로 확인함]** 실제 필드는 `{code, message, retriable}` — 같은
/// 세션에 답변 생성 중 다시 보내면 `code`가 `CHAT_BUSY`로 오고(메시지는
/// 저장되지 않음) — 전송 버튼을 `done`/`error`까지 비활성화해두는 클라이언트
/// 정책(`chat_screen.dart`의 `_isGenerating`)상 정상 경로에서는 거의 안
/// 나야 하지만, 혹시 와도 무관한 대체 조회(`_runFallbackSearch`)를 제안하지
/// 않도록 `chat_screen.dart`가 이 값을 확인한다.
class ChatErrorEvent extends ChatStreamEvent {
  const ChatErrorEvent({
    required this.code,
    required this.message,
    this.retriable = false,
  });
  final String code;
  final String message;
  final bool retriable;

  @override
  String toString() =>
      'ChatErrorEvent(code: $code, message: $message, retriable: $retriable)';
}

/// 알 수 없는 이벤트 타입. 명세에 새 이벤트가 추가되어도 파서가 죽지 않도록 한다.
class ChatUnknownEvent extends ChatStreamEvent {
  const ChatUnknownEvent({required this.type, required this.raw});
  final String type;
  final Map<String, dynamic> raw;

  @override
  String toString() => 'ChatUnknownEvent(type: $type, raw: $raw)';
}

/// `GET /api/v1/chat/sessions`의 세션 한 건. **[실서버로 확인함]** 필드명은
/// 명세서에 예시가 없어 처음엔 `session_id`/`last_active_at`로 가정했으나,
/// 실제로는 `id`(`session_id` 아님)였다 — 그 전까지는 실제로 세션이 있어도
/// `fetchSessions`가 항상 빈 목록을 반환하고 있었음(파싱 실패가 조용히
/// `null ?? []`로 흡수됨). `last_active_at`/`title`은 가정이 맞았다.
class ChatSessionSummary {
  const ChatSessionSummary({
    required this.sessionId,
    required this.title,
    required this.lastActiveAt,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      sessionId: json['id'] as String? ?? '',
      title: json['title'] as String?,
      lastActiveAt:
          DateTime.tryParse(json['last_active_at'] as String? ?? '')?.toLocal(),
    );
  }

  final String sessionId;
  final String? title;
  final DateTime? lastActiveAt;
}

class ChatSessionsPage {
  const ChatSessionsPage({required this.sessions, required this.hasMore});
  final List<ChatSessionSummary> sessions;
  final bool hasMore;
}

/// `GET /api/v1/chat/sessions/{session_id}/messages`의 메시지 한 건.
/// **[실서버로 확인함]** `id`/`role`/`created_at`은 가정이 맞았지만, 본문은
/// `text`가 아니라 `content`였다. **[실서버로 확인함]** `session_id`(중복 정보라
/// 안 씀)와 `tool_trace`(SSE `card` 이벤트와 동일한 `type`/`payload` 스키마의
/// 카드 데이터 배열, 값이 없으면 빈 배열)도 함께 온다 — `role`은 `user`/`assistant`
/// 두 값만 확인됨(`user`가 아니면 전부 AI 메시지로 취급하던 기존 가정과 일치).
/// [toolTrace]를 반영해 지난 대화를 이어볼 때도(`chat_screen.dart`의
/// `ChatResumeData`) 카드가 함께 복원된다(이전엔 텍스트만 복원되고 카드는
/// 유실됐음).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    required this.toolTrace,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      // [실서버로 확인함] `id`가 문자열(세션 id)이 아니라 숫자라 `as String?`이면
      // 캐스팅 예외가 난다 — `toString()`으로 안전하게 변환.
      id: json['id']?.toString() ?? '',
      role: json['role'] as String? ?? '',
      // [실서버로 확인함] `text`가 아니라 `content`였다.
      text: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      toolTrace: ((json['tool_trace'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((item) => ChatCardBlock(
                type: item['type'] as String? ?? '',
                payload: item['payload'] as Map<String, dynamic>? ?? const {},
              ))
          .toList(),
    );
  }

  final String id;
  final String role;
  final String text;
  final DateTime? createdAt;

  /// SSE `card` 이벤트와 동일한 모양의 카드 목록(`docs/API_SPEC.md`의 `### chat`
  /// 참고). 이 메시지에 카드가 없었으면 빈 리스트.
  final List<ChatCardBlock> toolTrace;
}

/// 커서 페이징 결과. **[실서버로 확인함]** `next_before`/`has_more`는 최상위가
/// 아니라 세션 목록과 동일하게 `data.page` 객체 안에 있었다(이전엔 최상위로
/// 가정해 `hasMore`도 아예 모델링 안 돼 있었음). [nextBefore]가 `null`이면 더
/// 가져올 이력이 없다는 뜻.
class ChatMessagesPage {
  const ChatMessagesPage({
    required this.messages,
    required this.hasMore,
    required this.nextBefore,
  });
  final List<ChatMessage> messages;
  final bool hasMore;
  final String? nextBefore;
}

/// 세션 목록/이력 조회, 세션 삭제 요청이 실패(`success: false`)했을 때 던지는 예외.
class ChatApiException implements Exception {
  ChatApiException(this.message, {this.code = '', this.retriable = false});
  final String code;
  final String message;
  final bool retriable;

  @override
  String toString() => message;
}

/// 채팅 메시지 전송 · 세션 관리 API(`docs/API_SPEC.md`의 `### chat` 절 참고).
/// 실제 백엔드 연동 전까지는 [MockChatApi]를 사용한다.
abstract class ChatApi {
  /// 대화 전송(`POST /api/v1/chat/stream`, SSE). 새 대화는 [sessionId]를 비워
  /// 보내고, 최초 [ChatMetaEvent]로 받은 `session_id`를 이후 메시지에 계속 실어
  /// 보내야 한다. **자동 재연결 금지** — 스트림이 끊기면(에러 포함) 호출부는 사용자가
  /// 버튼을 눌렀을 때만 다시 호출해야 한다(재연결 시 같은 요청이 중복 처리되어
  /// 공공데이터 호출·LLM 비용이 두 배로 나감).
  Stream<ChatStreamEvent> sendMessage(
      {required String text, String? sessionId});

  /// 세션 목록(`GET /api/v1/chat/sessions?limit=&offset=`, 최근 활동 순).
  Future<ChatSessionsPage> fetchSessions({int limit = 20, int offset = 0});

  /// 대화 이력(`GET /api/v1/chat/sessions/{session_id}/messages?before=`).
  /// 커서 페이징이므로 `offset`이 아니라 이전 페이지의 [ChatMessagesPage.nextBefore]를
  /// [before]에 넘긴다.
  Future<ChatMessagesPage> fetchMessages({
    required String sessionId,
    String? before,
  });

  /// 끊긴 스트림 이어받기(`GET /api/v1/chat/sessions/{session_id}/stream`,
  /// 새로고침 복구용). [sendMessage]와 동일하게 자동 재연결하지 않는다.
  Stream<ChatStreamEvent> resumeStream({required String sessionId});

  /// 세션 삭제(`DELETE /api/v1/chat/sessions/{session_id}`).
  Future<void> deleteSession({required String sessionId});
}

/// [ChatApi] 호출/응답을 [AppLog.logger]로 남기는 데코레이터. [MockChatApi]든
/// [DioChatApi]든 감싸는 대상과 무관하게 동일하게 동작하며, 채팅/지난 대화 화면을
/// 실행해 테스트할 때 어떤 요청을 보내고 어떤 이벤트를 받는지 콘솔에서 바로
/// 확인할 수 있게 한다.
class LoggingChatApi implements ChatApi {
  LoggingChatApi(this._inner);

  final ChatApi _inner;

  @override
  Stream<ChatStreamEvent> sendMessage({
    required String text,
    String? sessionId,
  }) async* {
    AppLog.logger
        .i('[ChatApi] sendMessage → text: "$text", sessionId: $sessionId');
    try {
      await for (final event
          in _inner.sendMessage(text: text, sessionId: sessionId)) {
        AppLog.logger.d('[ChatApi] ← $event');
        yield event;
      }
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[ChatApi] sendMessage 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Stream<ChatStreamEvent> resumeStream({required String sessionId}) async* {
    AppLog.logger.i('[ChatApi] resumeStream → sessionId: $sessionId');
    try {
      await for (final event in _inner.resumeStream(sessionId: sessionId)) {
        AppLog.logger.d('[ChatApi] ← $event');
        yield event;
      }
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[ChatApi] resumeStream 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ChatSessionsPage> fetchSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    AppLog.logger.i('[ChatApi] fetchSessions → limit: $limit, offset: $offset');
    try {
      final page = await _inner.fetchSessions(limit: limit, offset: offset);
      AppLog.logger.d(
          '[ChatApi] ← sessions: ${page.sessions.length}건, hasMore: ${page.hasMore}');
      return page;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[ChatApi] fetchSessions 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ChatMessagesPage> fetchMessages({
    required String sessionId,
    String? before,
  }) async {
    AppLog.logger
        .i('[ChatApi] fetchMessages → sessionId: $sessionId, before: $before');
    try {
      final page =
          await _inner.fetchMessages(sessionId: sessionId, before: before);
      AppLog.logger.d(
          '[ChatApi] ← messages: ${page.messages.length}건, hasMore: ${page.hasMore}, nextBefore: ${page.nextBefore}');
      return page;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[ChatApi] fetchMessages 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    AppLog.logger.i('[ChatApi] deleteSession → sessionId: $sessionId');
    try {
      await _inner.deleteSession(sessionId: sessionId);
      AppLog.logger.d('[ChatApi] ← deleteSession 완료');
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[ChatApi] deleteSession 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// `demo_script.dart`의 [DemoScript] 시나리오를 SSE 이벤트 형태로 흉내 내는 목업 구현.
/// 세션별로 진행 상황([_turnIndexBySession])을 기억해 매 호출마다 다음 데모 턴을
/// 이벤트로 변환해 내보낸다. 실제 백엔드가 아니므로 카드 [ChatCardEvent.payload]는
/// 데모 데이터를 JSON으로 옮기는 대신 최소한의 자리표시자만 담는다.
class MockChatApi implements ChatApi {
  final Map<String, int> _turnIndexBySession = {};
  int _nextSessionSeq = 1;

  @override
  Stream<ChatStreamEvent> sendMessage({
    required String text,
    String? sessionId,
  }) {
    final resolvedSessionId = (sessionId == null || sessionId.isEmpty)
        ? 'mock-session-${_nextSessionSeq++}'
        : sessionId;
    final turnIndex = _turnIndexBySession[resolvedSessionId] ?? 0;
    _turnIndexBySession[resolvedSessionId] = turnIndex + 1;
    return _eventsFor(resolvedSessionId, DemoScript.turnFor(turnIndex));
  }

  @override
  Stream<ChatStreamEvent> resumeStream({required String sessionId}) {
    // 데모 목업은 끊긴 스트림 개념이 없어 곧바로 완료 신호만 보낸다.
    return Stream.fromIterable(const [ChatDoneEvent()]);
  }

  Stream<ChatStreamEvent> _eventsFor(String sessionId, AiTurn turn) async* {
    yield ChatMetaEvent(sessionId: sessionId);
    final blocks = turn.blocks;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      switch (block) {
        case TextBlock(:final text):
          // 연속된 문장 블록은 호출부(`ChatScreen`)가 델타를 그대로 이어붙여 하나의
          // 문단으로 만들므로, 원래 있던 문단 구분이 사라지지 않도록 줄바꿈을 넣어
          // 보낸다(실제 백엔드라면 모델이 생성하는 텍스트 자체에 포함될 부분).
          final followedByText =
              i + 1 < blocks.length && blocks[i + 1] is TextBlock;
          yield ChatDeltaEvent(text: followedByText ? '$text\n\n' : text);
        case ForecastBlock():
          yield ChatCardEvent(
            type: 'forecast',
            payload: {'status': 'ok', 'has_data': true, 'demoBlock': block},
          );
        case RegionBlock():
          yield ChatCardEvent(
            type: 'region',
            payload: {'status': 'ok', 'has_data': true, 'demoBlock': block},
          );
        case NoDataBlock(:final spotName, :final actions):
          yield ChatCardEvent(
            type: 'no_data',
            payload: {
              'status': 'no_data',
              'has_data': false,
              'spot_name': spotName,
              'actions': actions,
              'demoBlock': block,
            },
          );
        case ChatCardBlock(:final type, :final payload):
          // 데모 스크립트에는 등장하지 않지만(항상 위 케이스들만 씀), AiBlock에
          // 새로 추가된 타입이라 exhaustive switch를 위해 다룬다 — 이미 실
          // 카드 모양(type/payload)이라 그대로 통과시킨다.
          yield ChatCardEvent(type: type, payload: payload);
      }
    }
    yield const ChatFinalEvent();
    yield const ChatDoneEvent();
  }

  @override
  Future<ChatSessionsPage> fetchSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    final entries = historyEntriesFor('ko');
    final sessions = [
      for (final (index, entry) in entries.indexed)
        ChatSessionSummary(
          sessionId: 'mock-history-$index',
          title: entry.title,
          lastActiveAt: DateTime.now().subtract(Duration(days: index)),
        ),
    ];
    return ChatSessionsPage(sessions: sessions, hasMore: false);
  }

  @override
  Future<ChatMessagesPage> fetchMessages({
    required String sessionId,
    String? before,
  }) async {
    return const ChatMessagesPage(
        messages: [], hasMore: false, nextBefore: null);
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {}
}

/// [AppConfig]의 `chat*Endpoint`로 실제 요청을 보내는 구현. `docs/API_SPEC.md`의
/// `### chat` 절을 따르되, 세션/메시지 응답의 `data` 하위 필드명(`sessions`/`messages`/
/// `has_more`/`next_before` 등)과 SSE 프레임의 `data` JSON 필드명은 아직 예시가
/// 전달되지 않아 가정한 값이다(확정되면 [_parseSseFrame]과 각 `fromJson`만 갱신하면 됨).
/// 인증(`Authorization` 헤더 등)도 앱 전역에 토큰 저장/부착 체계가 아직 없어 미구현
/// 상태다 — 실제 연동 전에 반드시 추가해야 한다.
class DioChatApi implements ChatApi {
  DioChatApi(this._dio);

  final Dio _dio;

  @override
  Stream<ChatStreamEvent> sendMessage({
    required String text,
    String? sessionId,
  }) {
    return _streamEvents(
      _dio.post<ResponseBody>(
        AppConfig.chatStreamEndpoint,
        // [실서버로 확인함] 새 대화를 `session_id: ''`(빈 문자열)로 보내면
        // 422(`INVALID_INPUT`, "session_id 값을 확인해주세요")로 거부된다 —
        // 서버는 필드 자체가 없는 것을 원한다. `docs/API_SPEC.md`의 "새
        // 대화는 session_id를 비워 보내고"는 "필드를 생략"으로 읽어야 한다.
        data: {
          if (sessionId != null && sessionId.isNotEmpty)
            'session_id': sessionId,
          'message': text,
        },
        options: Options(responseType: ResponseType.stream),
      ),
    );
  }

  @override
  Stream<ChatStreamEvent> resumeStream({required String sessionId}) {
    return _streamEvents(
      _dio.get<ResponseBody>(
        AppConfig.chatSessionStreamEndpoint(sessionId),
        options: Options(responseType: ResponseType.stream),
      ),
    );
  }

  @override
  Future<ChatSessionsPage> fetchSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.chatSessionsEndpoint,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = _unwrap(response, errorMessage: '세션 목록을 불러오지 못했어요.');
    // [실서버로 확인함] 목록 자체도 `sessions`가 아니라 `items`, `has_more`도
    // 최상위가 아니라 `page.has_more`였다(`ChatSessionSummary.fromJson` 참고).
    final sessions = ((data['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ChatSessionSummary.fromJson)
        .toList();
    final page = data['page'] as Map<String, dynamic>? ?? const {};
    return ChatSessionsPage(
      sessions: sessions,
      hasMore: page['has_more'] as bool? ?? false,
    );
  }

  @override
  Future<ChatMessagesPage> fetchMessages({
    required String sessionId,
    String? before,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppConfig.chatSessionMessagesEndpoint(sessionId),
      queryParameters: before == null ? null : {'before': before},
    );
    final data = _unwrap(response, errorMessage: '대화 이력을 불러오지 못했어요.');
    // [실서버로 확인함] 세션 목록과 마찬가지로 `messages`가 아니라 `items`.
    // `next_before`/`has_more`도 세션 목록과 동일하게 최상위가 아니라
    // `page` 객체 안에 있었다(이전엔 최상위 `next_before`로 잘못 가정해
    // 페이징이 필요해지는 순간 항상 `null`로 읽혔을 것).
    final messages = ((data['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    final page = data['page'] as Map<String, dynamic>? ?? const {};
    return ChatMessagesPage(
      messages: messages,
      hasMore: page['has_more'] as bool? ?? false,
      nextBefore: page['next_before'] as String?,
    );
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      AppConfig.chatSessionEndpoint(sessionId),
    );
    _unwrap(response, errorMessage: '세션을 삭제하지 못했어요.');
  }

  /// 공통 응답 봉투(`success`/`code`/`message`/`data`/`retriable`/`timestamp`)를
  /// 언래핑한다. `success`가 아니면 [ChatApiException]을 던진다.
  Map<String, dynamic> _unwrap(
    Response<Map<String, dynamic>> response, {
    required String errorMessage,
  }) {
    final envelope = response.data;
    if (envelope?['success'] != true) {
      throw ChatApiException(
        envelope?['message'] as String? ?? errorMessage,
        code: envelope?['code'] as String? ?? '',
        retriable: envelope?['retriable'] as bool? ?? false,
      );
    }
    return envelope?['data'] as Map<String, dynamic>? ?? const {};
  }

  /// `fetch`/`EventSource` 대신 [Dio]의 `ResponseType.stream`으로 받은 바이트
  /// 스트림을 SSE 프레임(빈 줄로 구분되는 `event:`/`data:` 라인 묶음) 단위로 잘라
  /// [ChatStreamEvent]로 변환한다. 요청 자체나 스트림 도중 실패해도 여기서 재시도하지
  /// 않는다(자동 재연결 금지 — 클래스 문서 참고).
  Stream<ChatStreamEvent> _streamEvents(
    Future<Response<ResponseBody>> request,
  ) async* {
    final Response<ResponseBody> response;
    try {
      response = await request;
    } on DioException catch (e) {
      // `responseType: ResponseType.stream`이라 에러 응답(4xx/5xx)도 디코딩되지
      // 않은 `ResponseBody`(원본 바이트 스트림)로 온다 — Dio의 기본 예외
      // 메시지는 상태 코드만 알려줄 뿐 서버가 실제로 왜 거부했는지(검증 오류
      // 상세 등)는 알려주지 않으므로, 그 바이트를 직접 읽어 로그에 남긴다
      // (재시도는 하지 않고 원래 예외를 그대로 다시 던짐).
      final body = e.response?.data;
      if (body is ResponseBody) {
        final bytes = await body.stream
            .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
        AppLog.logger.e(
          '[SSE] 요청 실패 (status: ${e.response?.statusCode}): '
          '${utf8.decode(bytes, allowMalformed: true)}',
        );
      }
      rethrow;
    }
    var buffer = '';
    await for (final chunk in response.data!.stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      var separatorIndex = buffer.indexOf('\n\n');
      while (separatorIndex != -1) {
        final event = _parseSseFrame(buffer.substring(0, separatorIndex));
        buffer = buffer.substring(separatorIndex + 2);
        if (event != null) yield event;
        separatorIndex = buffer.indexOf('\n\n');
      }
    }
  }

  ChatStreamEvent? _parseSseFrame(String frame) {
    String? eventType;
    final dataLines = <String>[];
    for (final line in frame.split('\n')) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (eventType == null) return null;
    final rawData = dataLines.join('\n');
    // 타입별 파싱(아래 switch)이 일부 필드를 버릴 수 있어, 서버가 실제로 보낸
    // 원본 그대로도 남긴다 — 스키마 확인/디버깅용.
    AppLog.logger.d('[SSE] event: $eventType, data: $rawData');
    final data = rawData.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawData) as Map<String, dynamic>;
    return switch (eventType) {
      'meta' => ChatMetaEvent(sessionId: data['session_id'] as String? ?? ''),
      'status' => ChatStatusEvent(
          message: data['label'] as String? ?? '',
          stage: data['stage'] as String?,
        ),
      'tool' => ChatToolEvent(name: data['name'] as String? ?? '', raw: data),
      'card' => ChatCardEvent(
          type: data['type'] as String? ?? '',
          payload: (data['payload'] as Map<String, dynamic>?) ?? const {},
        ),
      'delta' => ChatDeltaEvent(text: data['text'] as String? ?? ''),
      // [실서버로 확인함] 필드명은 `sources`가 아니라 `items`(각 항목은
      // `{name, note}`, 예: {"name": "출처: ⓒ한국관광공사", "note": ""}).
      'sources' => ChatSourcesEvent(
          sources: ((data['items'] as List<dynamic>?) ?? const [])
              .cast<Map<String, dynamic>>(),
        ),
      'final' => const ChatFinalEvent(),
      'done' => const ChatDoneEvent(),
      'error' => ChatErrorEvent(
          code: data['code'] as String? ?? '',
          message: data['message'] as String? ?? '',
          retriable: data['retriable'] as bool? ?? false,
        ),
      _ => ChatUnknownEvent(type: eventType, raw: data),
    };
  }
}
