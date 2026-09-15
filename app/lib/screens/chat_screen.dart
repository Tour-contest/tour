import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/areas_api.dart';
import 'package:nullnull/api/attractions_api.dart';
import 'package:nullnull/api/chat_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/data/logout_service.dart';
import 'package:nullnull/data/user_profile_storage.dart';
import 'package:nullnull/double_back_exit_mixin.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_drawer.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/confirm_dialog.dart';
import 'package:nullnull/widgets/push_drawer.dart';
import 'package:nullnull/widgets/chat/chat_fallback_prompt.dart';
import 'package:nullnull/widgets/chat/chat_input_bar.dart';
import 'package:nullnull/widgets/chat/streaming_ai_message.dart';
import 'package:nullnull/widgets/chat/user_message_bubble.dart';
import 'package:nullnull/widgets/fade_slide_in.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';
import 'package:nullnull/widgets/nullnull/profile_avatar.dart';
import 'package:nullnull/widgets/nullnull/theme_grid.dart';

sealed class _ChatEntry {
  const _ChatEntry(this.id);
  final int id;
}

class _UserChatEntry extends _ChatEntry {
  const _UserChatEntry(super.id, this.text);
  final String text;
}

/// `history_screen.dart`가 지난 대화를 이어보기 위해 `/chat` 라우트의 `extra`로
/// 넘기는 데이터. `ChatMessage.role`이 `user`가 아니면 전부 AI 메시지로
/// 취급한다(`docs/API_SPEC.md`에 실제 값 예시가 없어 가정, 실 데이터로 다른
/// 값이 확인되면 이 가정만 바꾸면 됨).
class ChatResumeData {
  const ChatResumeData({required this.sessionId, required this.messages});
  final String sessionId;
  final List<ChatMessage> messages;
}

class _AiChatEntry extends _ChatEntry {
  _AiChatEntry(super.id);

  /// 스트림이 완전히 끝난 뒤 한 번에 채워지는 완성된 블록 목록. 비어 있으면
  /// 아직 응답을 기다리는 중이라는 뜻(생각 중 표시)이고, 채워지는 순간
  /// `StreamingAiMessage`가 마운트되어 그 안에서 타이핑 연출을 직접 진행한다.
  final List<AiBlock> blocks = [];

  /// 타이핑 연출까지 끝까지 끝났는지(`StreamingAiMessage.onRevealComplete`).
  /// `false`인 동안 커서가 깜빡인다.
  bool done = false;

  /// 응답을 기다리는 동안 서버가 보낸 최신 진행 상태 라벨
  /// (`ChatStatusEvent.message`, 예: "질문 이해 중"). 아직 하나도 못 받았으면
  /// `_ThinkingIndicator`가 기본 문구(`chatThinkingLabel`)를 쓴다.
  String? statusLabel;

  /// `ChatSourcesEvent`로 받은 출처 목록(각 항목 `{name, note}`). 타이핑
  /// 연출이 끝난 뒤 `StreamingAiMessage` 하단에 보여준다.
  final List<Map<String, dynamic>> sources = [];

  /// `null`이면 평소처럼 진행 중(`blocks`가 비어있으면 생각 중 표시,
  /// 채워지면 `StreamingAiMessage`). SSE가 [blocks]를 하나도 못 채운 채
  /// 에러로 끝나면(레이트리밋 제외) `_send`가 이 값을 [ChatFallbackState.offered]로
  /// 바꿔 `_ThinkingIndicator` 대신 `ChatFallbackPrompt`를 보여준다
  /// (`## Architecture`의 `_send` 문서 참고). 대체 조회가 성공하면 [blocks]를
  /// 채우고 다시 `null`로 되돌려 기존 렌더링 경로를 그대로 탄다.
  ChatFallbackState? fallbackState;

  /// [fallbackState]가 [ChatFallbackState.offered]일 때 사용자가 버튼을
  /// 탭하면 이 원본 입력으로 `AttractionsApi.search`/`AreasApi.resolve`를
  /// 시도한다.
  String fallbackQuery = '';
}

/// docs/DESIGN.md 화면 2·3: 채팅(빈 상태 / 대화).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.chatApi,
    this.resume,
    this.areasApi,
    this.attractionsApi,
  });

  /// 테스트/향후 실 연동 전환을 위한 주입 지점(`history_screen.dart`와 동일한
  /// 패턴). 기본값은 실 서버(`nullnull.kr`) 연동.
  final ChatApi? chatApi;

  /// `history_screen.dart`에서 지난 대화를 이어볼 때만 넘어온다. `null`이면
  /// 평소처럼 빈 대화로 시작한다.
  final ChatResumeData? resume;

  /// SSE 에러 대체 흐름(`_runFallbackSearch`)에서 쓰는 `AreasApi`/`AttractionsApi`.
  /// [chatApi]와 동일한 테스트 주입 패턴. 기본값은 실 서버 연동.
  final AreasApi? areasApi;
  final AttractionsApi? attractionsApi;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with DoubleBackExitMixin<ChatScreen> {
  final List<_ChatEntry> _entries = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _drawerKey = GlobalKey<PushDrawerState>();
  final _appDrawerKey = GlobalKey<AppDrawerState>();
  // `nullnull.kr`(docs/API_SPEC.md `POST /api/v1/chat/stream`)에 실제로 붙는다.
  // 로그인 후에는 `ApiClient.create()`가 붙이는 `Authorization` 헤더로 인증까지
  // 됨을 확인함(로그인 전이거나 토큰 만료 시에는 401, `_send`가 실패 토스트만 띄움).
  late final ChatApi _chatApi =
      widget.chatApi ?? LoggingChatApi(DioChatApi(ApiClient.create()));
  // SSE 에러 대체 흐름(`_runFallbackSearch`)에서만 쓴다.
  late final AreasApi _areasApi =
      widget.areasApi ?? LoggingAreasApi(DioAreasApi(ApiClient.create()));
  late final AttractionsApi _attractionsApi = widget.attractionsApi ??
      LoggingAttractionsApi(DioAttractionsApi(ApiClient.create()));
  String? _sessionId;
  int _nextId = 0;

  /// 현재 AI 응답을 생성 중이면(=`_send`가 SSE 스트림을 구독 중이면) 그
  /// 스트림을 취소하는 콜백이 담긴다. `null`이면 생성 중이 아니라는 뜻 —
  /// `ChatInputBar`가 이 값의 유무로 전송/정지 버튼을 바꾼다.
  VoidCallback? _stopGeneration;
  bool get _isGenerating => _stopGeneration != null;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume == null) return;
    _applyResume(resume);
    _scrollToBottomSoon();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `history_screen.dart`가 `context.goNamed(RouteNames.chat, extra: ...)`로
    // 넘어와도, go_router는 같은 `/chat` 경로라 페이지 키가 그대로라 이 State를
    // 재사용한다(`initState`가 다시 불리지 않음) — `resume`이 바뀐 경우 여기서
    // 직접 반영해야 한다.
    final resume = widget.resume;
    if (resume == null || resume == oldWidget.resume) return;
    setState(() => _applyResume(resume));
    _scrollToBottomSoon();
  }

  void _applyResume(ChatResumeData resume) {
    _entries.clear();
    _nextId = 0;
    _sessionId = resume.sessionId;
    for (final message in resume.messages) {
      if (message.text.trim().isEmpty) continue;
      final id = _nextId++;
      _entries.add(message.role == 'user'
          ? _UserChatEntry(id, message.text)
          : (_AiChatEntry(id)
            ..blocks.add(TextBlock(message.text))
            // [실서버로 확인함] 메시지 응답의 `tool_trace`가 SSE `card` 이벤트와
            // 같은 모양이라 그대로 카드로 복원한다 — 문장 안에서 정확히 어느
            // 위치에 있었는지는 응답에 없어 항상 텍스트 뒤에 이어붙인다.
            ..blocks.addAll(message.toolTrace)
            ..done = true));
    }
  }

  @override
  void dispose() {
    // 화면을 떠날 때 진행 중인 SSE 스트림이 있으면 정리한다(연결을 그대로
    // 열어두지 않도록) — `_stopGeneration`의 후속 콜백들은 전부 `mounted`를
    // 먼저 확인하므로 이 시점에 호출해도 안전하다.
    _stopGeneration?.call();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// `docs/API_SPEC.md`의 `POST /api/v1/chat/stream`을 [ChatApi.sendMessage]로
  /// 호출해 SSE 이벤트를 순서대로 소비한다. 다른 생성형 AI 도구들처럼 응답을
  /// 일정한 리듬으로 보여주기 위해, [ChatDeltaEvent]/[ChatCardEvent]는 도착하는
  /// 대로 화면에 반영하지 않고 로컬 [buffer]에만 모아둔다 — 화면에는 대신
  /// [ChatStatusEvent]의 라벨([_AiChatEntry.statusLabel])만 실시간으로
  /// 갱신해 진행 상황을 보여준다. [ChatSourcesEvent]도 마찬가지로
  /// [capturedSources]에만 모아둔다. 스트림이 완전히 끝나면(정상 종료, 즉
  /// `final`/`done`까지 다 옴) 모아둔 블록·출처를 한 번에 [_AiChatEntry]에
  /// 채워 넣는다 — 그 순간 `StreamingAiMessage`가 처음 마운트되어 타이핑
  /// 연출은 그 위젯이 직접 담당한다(`onRevealComplete`가 끝나면
  /// [_AiChatEntry.done]을 켜는 것도 `_buildThread`에서 처리). 카드가 문장보다
  /// 먼저 도착할 수 있으므로 buffer에는 도착 순서 그대로 쌓는다. 실패해도
  /// **자동 재시도하지 않는다** — 사용자가 다시 입력해야 재요청된다.
  ///
  /// 이미 생성 중이면(`_isGenerating`) 무시한다 — `ChatInputBar`가 생성
  /// 중일 땐 버튼을 정지 아이콘으로 바꿔 이 경로로 다시 들어오지 않게
  /// 막지만, 방어적으로 한 번에 하나의 스트림만 열리도록 확인한다.
  /// `await for` 대신 `.listen()`으로 직접 구독을 들고 있는 이유는, 사용자가
  /// "정지" 버튼을 눌렀을 때 [StreamSubscription.cancel]로 SSE 연결 자체를
  /// 끊어야 하기 때문(`DioChatApi._streamEvents`가 내부에서 `await for`로
  /// 응답 바이트 스트림을 읽고 있어, 이 구독을 취소하면 그 안쪽 스트림
  /// 구독까지 함께 취소되어 실제로 커넥션이 닫힌다).
  void _send(String text) {
    if (_isGenerating) return;
    final userEntryId = _nextId++;
    final aiEntryId = _nextId++;
    final aiEntry = _AiChatEntry(aiEntryId);
    setState(() {
      _entries.add(_UserChatEntry(userEntryId, text));
      _entries.add(aiEntry);
    });
    unawaited(AnalyticsService.logChatMessageSent());
    _scrollToBottomSoon();

    final buffer = <AiBlock>[];
    final capturedSources = <Map<String, dynamic>>[];
    var stoppedByUser = false;

    void appendDelta(String chunk) {
      final last = buffer.isEmpty ? null : buffer.last;
      if (last is TextBlock) {
        buffer[buffer.length - 1] = TextBlock('${last.text}$chunk');
      } else {
        buffer.add(TextBlock(chunk));
      }
    }

    final completer = Completer<void>();
    // `completeWithError`가 아래에서 만들어질 `subscription`을 참조해야 해서
    // (에러 발생 시 직접 취소하기 위해), 먼저 선언만 해두고 `.listen()` 결과로
    // 나중에 대입한다(자기 참조 구독 취소의 표준적인 패턴).
    late final StreamSubscription<ChatStreamEvent> subscription;
    void completeWithError(Object error, [StackTrace? stackTrace]) {
      if (completer.isCompleted) return;
      // `ChatErrorEvent`는 스트림 자체의 에러가 아니라 정상적으로 온 데이터
      // 이벤트라 `cancelOnError`가 자동으로 구독을 끊어주지 않으므로 직접
      // 취소한다(이미 스트림 레벨 에러로 취소된 경우엔 그냥 중복 호출이라
      // 안전하게 무시됨).
      subscription.cancel();
      completer.completeError(error, stackTrace ?? StackTrace.current);
    }

    subscription =
        _chatApi.sendMessage(text: text, sessionId: _sessionId).listen(
            (event) {
              switch (event) {
                case ChatMetaEvent(:final sessionId):
                  _sessionId = sessionId;
                case ChatStatusEvent(:final message):
                  if (!mounted) return;
                  setState(() => aiEntry.statusLabel = message);
                  _scrollToBottomSoon();
                case ChatDeltaEvent(text: final chunk):
                  appendDelta(chunk);
                case ChatCardEvent(:final type, :final payload):
                  buffer.add(event.demoBlock ??
                      ChatCardBlock(type: type, payload: payload));
                case ChatSourcesEvent(:final sources):
                  capturedSources.addAll(sources);
                case ChatErrorEvent(:final message):
                  completeWithError(ChatApiException(message));
                case ChatFinalEvent():
                case ChatToolEvent():
                case ChatDoneEvent():
                case ChatUnknownEvent():
                  break;
              }
            },
            onError: completeWithError,
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            cancelOnError: true);

    setState(() {
      _stopGeneration = () {
        stoppedByUser = true;
        subscription.cancel();
        if (!completer.isCompleted) completer.complete();
      };
    });

    completer.future.then((_) {
      if (mounted) setState(() => _stopGeneration = null);
      if (!mounted) return;
      // 아직 아무것도 안 온 채로(=`_ThinkingIndicator`가 떠 있는 채로) 멈춘
      // 경우엔 보여줄 게 없으므로 엔트리 자체를 지운다 — 그대로 두면
      // `entry.blocks`가 계속 비어있어 더 이상 갱신되지 않는 "생각 중" 표시가
      // 화면에 영영 멈춰 남게 된다.
      if (stoppedByUser && buffer.isEmpty && capturedSources.isEmpty) {
        setState(() => _entries.removeWhere((entry) => entry.id == aiEntryId));
        return;
      }
      setState(() {
        aiEntry.blocks.addAll(buffer);
        aiEntry.sources.addAll(capturedSources);
        // 사용자가 직접 멈춘 경우 지금까지 모인 걸 곧바로 다 보여준다(타이핑
        // 연출 없이) — 이미 멈추기로 한 응답을 다시 글자 단위로 재생하는 건
        // 어색하다.
        if (stoppedByUser) aiEntry.done = true;
      });
      _scrollToBottomSoon();
    }, onError: (Object e, StackTrace stackTrace) {
      AppLog.logger.e('채팅 메시지 전송 실패', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _stopGeneration = null);
      if (!mounted) return;
      // 문장/카드를 하나도 못 받은 채(=아직 사용자에게 보여줄 게 없는 채) 끝났고,
      // 분당 10회 제한(429)처럼 다시 눌러야 하는 상황이 아니면 대체 흐름을
      // 제안한다 — 이미 부분 답변이 떠 있으면 지금처럼 그냥 실패로 끝낸다.
      final isRateLimited = e is DioException && e.response?.statusCode == 429;
      if (buffer.isEmpty && !isRateLimited) {
        setState(() {
          aiEntry.fallbackQuery = text;
          aiEntry.fallbackState = ChatFallbackState.offered;
        });
        return;
      }
      setState(() => _entries.removeWhere((entry) => entry.id == aiEntryId));
      AppToast.show(
        AppLocalizations.of(context)!.chatSendFailedToast,
        type: AppToastType.info,
      );
    });
  }

  /// `ChatFallbackPrompt`의 "다른 방식으로 찾아보기" 버튼 탭 시 호출된다.
  /// `entry.fallbackQuery`(원본 사용자 입력)를 `AttractionsApi.search`에 먼저
  /// 시도하고, 결과가 없으면 `AreasApi.resolve`(+ 단일 지역이면 `fetchOverview`)를
  /// 시도하는 best-effort 매칭이다 — 의도 파악 로직 없이 원문 그대로 넘긴다.
  /// `resolve`가 `ambiguous`면(선택 UI가 아직 없어) 자동으로 후보를 고르지
  /// 않고 그대로 실패로 처리한다(`docs/API_SPEC.md`의 "구현 주의").
  Future<void> _runFallbackSearch(_AiChatEntry entry) async {
    setState(() => entry.fallbackState = ChatFallbackState.searching);
    try {
      final searchResult =
          await _attractionsApi.search(keyword: entry.fallbackQuery);
      if (searchResult.items.isNotEmpty) {
        _applyFallbackResult(
            entry, _attractionListCard(entry.fallbackQuery, searchResult));
        return;
      }

      final resolved = await _areasApi.resolve(query: entry.fallbackQuery);
      final area = resolved.area;
      if (resolved.status == 'ok' && area != null) {
        final overview = await _areasApi.fetchOverview(signguCd: area.signguCd);
        _applyFallbackResult(entry, _crowdCard(overview));
        return;
      }

      if (!mounted) return;
      setState(() => entry.fallbackState = ChatFallbackState.exhausted);
    } catch (e, stackTrace) {
      AppLog.logger.e('대체 흐름 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => entry.fallbackState = ChatFallbackState.exhausted);
    }
  }

  /// 대체 흐름이 뭔가를 찾았을 때, 새 카드 UI를 따로 만드는 대신 캡션
  /// 문장(`chatFallbackResultCaption`) + 카드를 [entry.blocks]에 채워 넣고
  /// [fallbackState]를 되돌려 기존 `StreamingAiMessage`/`ChatCardView` 렌더링
  /// 경로를 그대로 태운다(`_buildThread` 참고).
  void _applyFallbackResult(_AiChatEntry entry, ChatCardBlock card) {
    if (!mounted) return;
    setState(() {
      entry.fallbackState = null;
      entry.blocks
        ..add(
            TextBlock(AppLocalizations.of(context)!.chatFallbackResultCaption))
        ..add(card);
      entry.done = true;
    });
  }

  /// `AttractionsApi.search` 결과를 실 서버 `attraction_list` 카드와 같은
  /// 페이로드 모양(`docs/API_SPEC.md`의 `### chat`에서 확인됨)으로 변환해
  /// 기존 `ChatCardView`가 그대로 그릴 수 있게 한다. `category`엔 원본 검색어를
  /// 넣어 제목이 자연스럽게 읽히도록 한다(실 카드의 `category`처럼 태그성
  /// 문구는 아니지만, 이 화면에선 사용자가 뭘 물어봤는지 보여주는 편이 낫다).
  ChatCardBlock _attractionListCard(
      String query, AttractionSearchResult result) {
    return ChatCardBlock(type: 'attraction_list', payload: {
      'status': 'ok',
      'category': query,
      'signgu_nm': result.items.first.signguNm ?? '',
      'items': [
        for (final item in result.items)
          {'title': item.title, 'addr1': item.addr1, 'addr2': item.addr2},
      ],
    });
  }

  /// `AreasApi.fetchOverview` 결과를 실 서버 `crowd` 카드와 같은 페이로드
  /// 모양으로 변환한다(`AreaCrowdSnapshot`의 `Level` 매핑을 다시 문자열 키로
  /// 되돌리는 이유: `ChatCardView`의 `CrowdCardData.fromJson`이 그 키를 기대함).
  /// **[실서버로 확인함]** 실 서버 `crowd` 카드의 키는 한글 라벨이 아니라
  /// 영문(`crowded`/`normal`/`quiet`)이라, 이 폴백이 만드는 카드도 실 카드와
  /// 완전히 같은 모양이 되도록 영문 키로 맞췄다.
  ChatCardBlock _crowdCard(AreaCrowdSnapshot snapshot) {
    String levelKey(Level level) => switch (level) {
          Level.busy => 'crowded',
          Level.quiet => 'quiet',
          Level.normal => 'normal',
        };
    return ChatCardBlock(type: 'crowd', payload: {
      'status': 'ok',
      'signgu_nm': snapshot.signguNm,
      'summary': {
        for (final entry in snapshot.counts.entries)
          levelKey(entry.key): entry.value,
      },
      'samples': {
        for (final entry in snapshot.samples.entries)
          levelKey(entry.key): [
            for (final sample in entry.value)
              {
                'name': sample.name,
                'rate': sample.rate,
                'content_id': sample.contentId,
                'image': sample.image,
              },
          ],
      },
    });
  }

  void _newChat() {
    setState(() {
      _entries.clear();
      _sessionId = null;
    });
  }

  /// `AppDrawer`의 "최근" 미리보기 항목 탭 시 호출된다. `history_screen.dart`의
  /// `_openSession`과 동일한 조회(`ChatApi.fetchMessages`) 후, 이 화면
  /// 자신이 이미 `/chat`이므로 `goNamed`로 스택을 새로 쌓지 않고 `didUpdateWidget`이
  /// `resume` 변경을 감지해 반영하는 기존 메커니즘을 그대로 이용한다. 성공
  /// 시에만 드로어를 닫고, 실패하면 드로어를 연 채로 토스트만 안내해 사용자가
  /// 다른 항목을 다시 시도할 수 있게 한다.
  Future<void> _openDrawerSession(ChatSessionSummary session) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final page = await _chatApi.fetchMessages(sessionId: session.sessionId);
      if (!mounted) return;
      _drawerKey.currentState?.close();
      context.goNamed(
        RouteNames.chat,
        extra: ChatResumeData(
            sessionId: session.sessionId, messages: page.messages),
      );
    } catch (e, stackTrace) {
      AppLog.logger.e('드로어에서 대화 이력 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      AppToast.show(l10n.historyResumeError, type: AppToastType.info);
    }
  }

  /// 바닥으로 스크롤한다. [animate]가 `true`면 부드럽게 애니메이션하고,
  /// `false`면 즉시 이동(`jumpTo`)한다 — `onRevealProgress`처럼 타이핑 연출
  /// 중 20ms 간격으로 계속 호출되는 경우 매번 새 `animateTo`를 걸면 이전
  /// 애니메이션이 그때마다 취소돼(특히 실기기에서 프레임이 밀리면 그 간격조차
  /// 안 지켜져) 화면이 거의 못 움직이고 멈춘 것처럼 보인다 — 그런 고빈도
  /// 호출에는 `animate: false`로 즉시 스냅시켜 매 프레임 바닥에 붙어 있게
  /// 한다(이 정도 빈도면 매번 즉시 이동해도 눈에는 부드럽게 흘러내리는 것처럼
  /// 보인다). 메시지 전송 직후·응답 완료 시처럼 드물게 호출되는 곳만 그대로
  /// 애니메이션을 유지한다.
  void _scrollToBottomSoon({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PushDrawer(
      key: _drawerKey,
      drawer: AppDrawer(
        key: _appDrawerKey,
        chatApi: _chatApi,
        onNewChat: _newChat,
        onClose: () => _drawerKey.currentState?.close(),
        onOpenSession: _openDrawerSession,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final drawer = _drawerKey.currentState;
          if (drawer != null && drawer.isOpen) {
            drawer.close();
            return;
          }
          handleBackPress();
        },
        child: Scaffold(
          backgroundColor: colors.loginBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader(
                  backgroundColor: colors.loginBackground,
                  leading: SvgPicture.asset('assets/images/icon_menu.svg'),
                  onLeadingTap: () {
                    _appDrawerKey.currentState?.refresh();
                    _drawerKey.currentState?.open();
                  },
                  leadingTooltip: l10n.chatHistoryTooltip,
                  trailing: const Center(child: _ProfileAvatarButton()),
                ),
                Expanded(
                  child: SelectionArea(
                    child: _entries.isEmpty
                        ? _EmptyState(onPromptTap: _send)
                        : _buildThread(),
                  ),
                ),
                ChatInputBar(
                  controller: _inputController,
                  onSend: _send,
                  isGenerating: _isGenerating,
                  onStop: _stopGeneration,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThread() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          key: ValueKey(entry.id),
          padding: const EdgeInsets.only(bottom: 20),
          child: FadeSlideIn(
            child: switch (entry) {
              _UserChatEntry(:final text) => UserMessageBubble(text: text),
              _AiChatEntry()
                  when entry.blocks.isEmpty && entry.fallbackState == null =>
                _ThinkingIndicator(label: entry.statusLabel),
              _AiChatEntry() when entry.blocks.isEmpty => ChatFallbackPrompt(
                  state: entry.fallbackState!,
                  offeredMessage: l10n.chatFallbackOfferedMessage,
                  exhaustedMessage: l10n.chatFallbackExhaustedMessage,
                  actionLabel: l10n.chatFallbackActionLabel,
                  onSearch: () => _runFallbackSearch(entry),
                ),
              _AiChatEntry() => ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamingAiMessage(
                        key: ValueKey('stream-${entry.id}'),
                        blocks: entry.blocks,
                        streaming: !entry.done,
                        sources: entry.sources,
                        onActionTap: _send,
                        onRevealProgress: () =>
                            _scrollToBottomSoon(animate: false),
                        onRevealComplete: entry.done
                            ? null
                            : () {
                                if (!mounted) return;
                                setState(() => entry.done = true);
                              },
                      ),
                    ],
                  ),
                ),
            },
          ),
        );
      },
    );
  }
}

/// [ChatApi.sendMessage] 스트림이 끝나기를 기다리는 동안 보여주는 안내.
/// `StreamingAiMessage`의 "널널" 라벨 행과 같은 스타일(골드 점 + 라벨)을 쓴다.
/// [label]이 있으면(`ChatStatusEvent`로 받은 진행 상태) 그걸, 없으면 기본
/// 문구(`chatThinkingLabel`)를 보여준다.
/// 응답이 아직 하나도 안 온(=`entry.blocks`가 비어있는) 동안만 보이는 표시.
/// 이 상태임을 알아보기 쉽도록 마스코트를 천천히 위아래로 움직인다(사용자
/// 요청) — 실제 응답이 오기 시작해(`entry.blocks`가 채워져) `StreamingAiMessage`로
/// 넘어가는 순간 이 위젯째 사라지므로, 애니메이션도 자연히 함께 멈춘다.
/// `StreamingAiMessage` 헤더의 마스코트는 별도 요청으로 애니메이션을 뺐던
/// 적이 있어(`## Architecture` 참고) 이 위젯에는 적용하지 않는다.
class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({this.label});

  final String? label;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bob;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _bob = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _bob,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _bob.value),
            child: child,
          ),
          child: const Mascot(size: 48),
        ),
        const SizedBox(width: 12),
        Text(
          widget.label ?? l10n.chatThinkingLabel,
          style: AppTextStyles.body(fontSize: 13, color: colors.ink),
        ),
      ],
    );
  }
}

/// 헤더 우측 프로필 아바타. 탭하면 아이콘 바로 아래에 "설정"/"로그아웃" 2개
/// 메뉴가 담긴 팝업(`popup_slot.png` 배경)을 띄운다. `AppHeader`에 더 이상
/// `onTrailingTap`을 넘기지 않고, 이 위젯이 직접 제스처와 팝업을 관리한다.
class _ProfileAvatarButton extends StatefulWidget {
  const _ProfileAvatarButton();

  @override
  State<_ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<_ProfileAvatarButton> {
  // `AppHeader`의 `_HeaderSlot`이 아이콘 슬롯에 쓰는 탭 영역 크기(44)와 맞춰
  // 팝업이 실제 보이는 아이콘 바로 아래에 붙도록 한다.
  static const double _slotSize = 44;

  // 지원하는 SNS 로그인 수단이 카카오 하나뿐이라 항상 이 값으로 고정한다
  // ("최근 로그인" 수단 저장 기능은 삭제됨).
  final SnsProvider _provider = SnsProvider.kakao;

  // 카카오 로그인 성공 시 저장해둔 실제 닉네임/프로필 사진(`login_screen.dart`의
  // `_saveKakaoProfile`). 없으면(네이버 mock 로그인, 동의 안 함 등) 기존처럼
  // `DemoUser` 목업 닉네임의 첫 글자로 대체한다(`settings_screen.dart`의
  // `_ProfileSummary`와 동일한 패턴).
  UserProfile? _profile;

  final _menuLink = LayerLink();
  OverlayEntry? _menuEntry;

  /// 로그아웃 요청(`LogoutService.logout`) 진행 중 화면 전체를 덮어 터치를
  /// 막고 로딩 인디케이터를 보여주는 별도 오버레이(`settings_screen.dart`의
  /// `_isLoggingOut` + `Stack`/`ColoredBox`와 같은 목적이지만, 이 위젯은 전체
  /// 화면 `Scaffold`를 갖고 있지 않아 같은 `OverlayEntry` 메커니즘(`_menuEntry`
  /// 참고)으로 구현한다).
  OverlayEntry? _loadingEntry;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _closeMenu();
    _hideLoadingOverlay();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileStorage.read();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
  }

  void _toggleMenu() {
    if (_menuEntry != null) {
      _closeMenu();
      return;
    }
    final overlayState = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _ProfileMenuOverlay(
        link: _menuLink,
        onDismiss: _closeMenu,
        onSettingsTap: _openSettings,
        onLogoutTap: _confirmLogout,
      ),
    );
    _menuEntry = entry;
    overlayState.insert(entry);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _showLoadingOverlay() {
    final overlayState = Overlay.of(context);
    final entry =
        OverlayEntry(builder: (_) => const _FullScreenLoadingOverlay());
    _loadingEntry = entry;
    overlayState.insert(entry);
  }

  void _hideLoadingOverlay() {
    _loadingEntry?.remove();
    _loadingEntry = null;
  }

  void _openSettings() {
    _closeMenu();
    context.pushNamed(RouteNames.settings);
  }

  Future<void> _confirmLogout() async {
    _closeMenu();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: l10n.settingsLogoutDialogTitle,
        message: l10n.settingsLogoutDialogMessage,
        confirmLabel: l10n.settingsLogout,
      ),
    );
    if (confirmed != true || !mounted) return;
    _showLoadingOverlay();
    await LogoutService.logout(_provider);
    _hideLoadingOverlay();
    if (!mounted) return;
    context.goNamed(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final nickname =
        _profile?.nickname ?? DemoUser.nicknameFor(_provider, languageCode);
    return CompositedTransformTarget(
      link: _menuLink,
      child: GestureDetector(
        onTap: _toggleMenu,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _slotSize,
          height: _slotSize,
          child: ProfileAvatar(
            size: _slotSize,
            imageUrl: _profile?.profileImageUrl,
            initial: nickname.substring(0, 1),
            initialStyle: AppTextStyles.heading(
                fontSize: 18, color: colors.ink, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 로그아웃 진행 중 화면 전체를 덮는 로딩 오버레이. `login_screen.dart`의
/// `_isLoggingIn` 오버레이(`ColoredBox` + `CircularProgressIndicator`)와 같은
/// 모양이지만, 여기는 `Scaffold` 하나가 아니라 전역 `Overlay`에 직접 얹는
/// 형태라 `Positioned.fill`로 화면 전체를 채운다.
class _FullScreenLoadingOverlay extends StatelessWidget {
  const _FullScreenLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: colors.scrim,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// [_ProfileAvatarButton] 탭 시 뜨는 팝업. 화면 전체를 덮는 투명 배리어로
/// 바깥 탭을 감지해 닫고, `CompositedTransformFollower`로 아바타 바로 아래에
/// 메뉴 카드를 붙인다.
class _ProfileMenuOverlay extends StatelessWidget {
  const _ProfileMenuOverlay({
    required this.link,
    required this.onDismiss,
    required this.onSettingsTap,
    required this.onLogoutTap,
  });

  final LayerLink link;
  final VoidCallback onDismiss;
  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: _ProfileMenuCard(
            onSettingsTap: onSettingsTap,
            onLogoutTap: onLogoutTap,
          ),
        ),
      ],
    );
  }
}

/// `popup_slot.png`(2:1 비율, 다른 `*_slot.png` 배경과 같은 2배율 원칙 적용)를
/// 154×77 크기로 깔고 그 위에 "설정"/"로그아웃" 2행을 올린 메뉴 카드.
class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.onSettingsTap,
    required this.onLogoutTap,
  });

  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  static const double _width = 154;
  static const double _height = 77;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/popup_slot.png', fit: BoxFit.fill),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProfileMenuItem(
                    label: l10n.commonSettings,
                    onTap: onSettingsTap,
                    isFirst: true,
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuItem(
                    label: l10n.settingsLogout,
                    onTap: onLogoutTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.label,
    required this.onTap,
    this.isFirst = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(label,
            textScaler: TextScaler.noScaling,
            style: AppTextStyles.body(fontSize: 15, color: colors.ink)
                .copyWith(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  // 지원하는 SNS 로그인 수단이 카카오 하나뿐이라 항상 이 값으로 고정한다
  // ("최근 로그인" 수단 저장 기능은 삭제됨).
  final SnsProvider _provider = SnsProvider.kakao;

  // `_ProfileAvatarButtonState`/`settings_screen.dart`의 `_ProfileSummary`와
  // 동일한 패턴 — 카카오 로그인으로 받아온 실제 닉네임이 있으면 그걸, 없으면
  // (동의 안 함, 조회 실패 등) `DemoUser` 목업으로 대체한다.
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileStorage.read();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final nickname =
        _profile?.nickname ?? DemoUser.nicknameFor(_provider, languageCode);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                // 이전엔 `Center`로 전체 콘텐츠를 세로 중앙 정렬했는데,
                // 그러면 글자 크기 설정이 커져 `ThemeGrid`가 늘어날수록
                // 전체 높이가 커지면서 위쪽 마스코트/인사말이 위로 밀려
                // 보이는 문제가 있었다(사용자 요청으로 상단 고정 + 여백으로
                // 전환 — 내용이 늘어나도 마스코트 위치는 고정되고 아래쪽
                // 여유 공간만 줄어든다).
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: 120,
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colors.inputBarBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accent.withAlpha(56),
                              blurRadius: 44,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Mascot(size: 70),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.chatGreeting(nickname),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading(
                          fontSize: 18,
                          color: colors.ink,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ThemeGrid(onThemeTap: widget.onPromptTap),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
