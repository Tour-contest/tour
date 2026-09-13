import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/chat_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/chat_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';

/// 지난 대화 목록 화면. `docs/API_SPEC.md`의 `GET /api/v1/chat/sessions`(최근
/// 활동 순)를 [ChatApi.fetchSessions]로 호출해 보여준다. `docs/DESIGN.md`에는
/// 아직 이 화면의 레이아웃 스펙이 없어 `place_detail_screen.dart`와 같은 다른
/// 화면의 색상/타이포그래피 컨벤션을 그대로 따라 구성했다. 항목을 탭하면
/// [ChatApi.fetchMessages]로 그 세션의 이력을 불러온 뒤 [ChatScreen]을
/// [ChatResumeData]와 함께 `goNamed`로 띄운다(`ChatScreen`이 뒤로가기 시 앱을
/// 종료하는 단일 홈 화면 전제라 `pushNamed`로 쌓지 않고 스택을 통째로
/// 교체함 — 로그인 성공 때와 동일한 방식).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.chatApi});

  /// 테스트/향후 실 연동 전환을 위한 주입 지점. 기본값은 [MockChatApi].
  final ChatApi? chatApi;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // `chat_screen.dart`와 동일하게 실 서버(`nullnull.kr`) 연동 상태를 유지한다.
  // 로그인 전이거나 액세스 토큰이 만료된 상태로 `GET /api/v1/chat/sessions`를
  // 호출하면 401이 오는데, 화면은 이를 그대로 에러 안내 + 재시도 버튼으로
  // 보여준다(`api_client.dart`의 `_AuthInterceptor`가 401을 가로채 자동으로
  // 토큰을 갱신한 뒤 재시도하므로, 로그인된 상태에서는 정상 조회됨).
  late final ChatApi _chatApi =
      widget.chatApi ?? LoggingChatApi(DioChatApi(ApiClient.create()));
  List<ChatSessionSummary>? _sessions;
  bool _isLoading = true;
  bool _hasError = false;

  /// 세션 이력 조회(`_openSession`) 진행 중에는 화면 터치를 막고 로딩
  /// 인디케이터를 보여준다(`login_screen.dart`의 `_isLoggingIn`과 동일한
  /// `PopScope` + `Stack`/`ColoredBox` 패턴).
  bool _isOpeningSession = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// `ChatScreen._send`와 같은 패턴(try/catch + setState)으로 [ChatApi]
  /// 호출을 처리한다. `FutureBuilder` 대신 이 방식을 쓰는 이유: 위젯 테스트
  /// 환경에서 `FutureBuilder`에 넘긴 Future가 (테스트용 mock처럼) 리스너가
  /// 붙기 전에 곧바로 실패하면 Dart의 미해결 Future 오류 감지가 오탐하는
  /// 사례가 있어, 에러를 항상 이 함수 안에서 직접 잡아 상태로 변환해둔다.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final page = await _chatApi.fetchSessions();
      if (!mounted) return;
      setState(() {
        _sessions = page.sessions;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLog.logger.e('지난 대화 목록 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// `ChatApi.fetchMessages`로 세션 이력을 불러와 [ChatScreen]을 이어보기
  /// 상태로 띄운다. 실패하면 [historyResumeError] 토스트만 안내한다.
  Future<void> _openSession(ChatSessionSummary session) async {
    if (_isOpeningSession) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isOpeningSession = true);
    try {
      final page = await _chatApi.fetchMessages(sessionId: session.sessionId);
      if (!mounted) return;
      context.goNamed(
        RouteNames.chat,
        extra: ChatResumeData(
            sessionId: session.sessionId, messages: page.messages),
      );
    } catch (e, stackTrace) {
      AppLog.logger.e('대화 이력 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isOpeningSession = false);
      AppToast.show(l10n.historyResumeError, type: AppToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_isOpeningSession,
      child: Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: Stack(
            children: [
              Column(
                children: [
                  PlainHeader(title: l10n.historyTitle),
                  Expanded(child: _buildBody(colors, l10n)),
                ],
              ),
              if (_isOpeningSession)
                ColoredBox(
                  color: colors.scrim,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors, AppLocalizations l10n) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (_hasError) {
      return _HistoryMessage(
        message: l10n.historyErrorMessage,
        actionLabel: l10n.historyRetryButton,
        onActionTap: _load,
      );
    }
    final sessions = _sessions!;
    if (sessions.isEmpty) {
      return _HistoryMessage(message: l10n.historyEmptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => Container(height: 1, color: colors.divider),
      itemBuilder: (context, index) => _HistoryTile(
        session: sessions[index],
        onTap: () => _openSession(sessions[index]),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session, required this.onTap});

  final ChatSessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final lastActiveAt = session.lastActiveAt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.title ?? l10n.historyUntitledSession,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(fontSize: 16, color: colors.ink),
              ),
            ),
            if (lastActiveAt != null) ...[
              const SizedBox(width: 10),
              Text(
                DateFormat('MM.dd').format(lastActiveAt),
                style: AppTextStyles.body(fontSize: 13, color: colors.ink600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 로딩 실패/빈 목록 안내. [actionLabel]/[onActionTap]을 함께 주면 재시도
/// 버튼도 보여준다(로딩 실패 케이스).
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 14, color: colors.ink600),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onActionTap,
              child: Text(
                actionLabel!,
                style: AppTextStyles.body(
                    fontSize: 14, color: colors.accentBright),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
