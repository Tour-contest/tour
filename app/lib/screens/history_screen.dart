import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/chat_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';

/// 지난 대화 목록 화면. `docs/API_SPEC.md`의 `GET /api/v1/chat/sessions`(최근
/// 활동 순)를 [ChatApi.fetchSessions]로 호출해 보여준다. `docs/DESIGN.md`에는
/// 아직 이 화면의 레이아웃 스펙이 없어 `place_detail_screen.dart`와 같은 다른
/// 화면의 색상/타이포그래피 컨벤션을 그대로 따라 구성했다. 항목을 탭하면 대화를
/// 이어보는 동작이 이상적이지만, 그러려면 `ChatApi.fetchMessages` 연동과
/// `ChatScreen`이 기존 세션을 이어받는 기능이 별도로 필요해 아직은 안내
/// 토스트만 띄우는 mock 동작이다(`place_detail_screen.dart`의 지도/전화 버튼과
/// 동일한 패턴).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.chatApi});

  /// 테스트/향후 실 연동 전환을 위한 주입 지점. 기본값은 [MockChatApi].
  final ChatApi? chatApi;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // `chat_screen.dart`와 동일하게 실 서버(`nullnull.kr`) 연동 상태를 유지한다.
  // 인증 토큰 체계가 없어 `GET /api/v1/chat/sessions`도 401로 실패하는 상태이며,
  // 화면은 이를 그대로 에러 안내 + 재시도 버튼으로 보여준다.
  late final ChatApi _chatApi =
      widget.chatApi ?? LoggingChatApi(DioChatApi(ApiClient.create()));
  List<ChatSessionSummary>? _sessions;
  bool _isLoading = true;
  bool _hasError = false;

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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Column(
          children: [
            PlainHeader(title: l10n.historyTitle),
            Expanded(child: _buildBody(colors, l10n)),
          ],
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
        onTap: () => AppToast.show(l10n.historyResumeComingSoon,
            type: AppToastType.info),
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
