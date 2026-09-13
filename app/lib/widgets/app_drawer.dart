import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/chat_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// docs/assets/images/drawer_screen.png 시안: 로고, "최근" 대화 목록, 하단
/// 설정 원형 버튼 + "새 채팅" pill 버튼으로 구성된 드로어. `PushDrawer`(오버레이가
/// 아닌 본문을 밀어내는 방식)의 `drawer` 슬롯에 들어가므로, 항목을 고르거나
/// 닫기를 원할 때 `Navigator.pop`이 아니라 [onClose]로 직접 닫아야 한다.
/// "최근" 목록은 `history_screen.dart`와 같은 `GET /api/v1/chat/sessions`
/// (`ChatApi.fetchSessions`)를 호출해 최근 세션 몇 개만 미리보기로 보여준다.
class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    required this.onNewChat,
    required this.onClose,
    this.chatApi,
  });

  final VoidCallback onNewChat;
  final VoidCallback onClose;

  /// 테스트/향후 실 연동 전환을 위한 주입 지점(`history_screen.dart`와 동일한
  /// 패턴). `chat_screen.dart`는 자신이 쓰는 `_chatApi`를 그대로 넘겨 별도
  /// `Dio` 인스턴스가 중복 생성되지 않게 한다.
  final ChatApi? chatApi;

  @override
  State<AppDrawer> createState() => AppDrawerState();
}

/// `PushDrawerState`와 같은 이유로 public — `chat_screen.dart`가
/// `GlobalKey<AppDrawerState>`로 들고 있다가 드로어를 열 때마다 [refresh]를
/// 호출해 방금 보낸 메시지로 생기거나 갱신된 세션을 반영한다.
class AppDrawerState extends State<AppDrawer> {
  /// 드로어는 미리보기 목적이라 전체 목록(`history_screen.dart`)보다 적게
  /// 가져온다.
  static const int _previewLimit = 8;

  late final ChatApi _chatApi =
      widget.chatApi ?? LoggingChatApi(DioChatApi(ApiClient.create()));

  List<ChatSessionSummary>? _sessions;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// `history_screen.dart`의 `_load()`와 동일한 try/catch + `setState` 패턴.
  Future<void> refresh() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final page = await _chatApi.fetchSessions(limit: _previewLimit);
      if (!mounted) return;
      setState(() {
        _sessions = page.sessions;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLog.logger.e('드로어 최근 대화 목록 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _newChat() {
    widget.onNewChat();
    widget.onClose();
  }

  void _openSettings() {
    widget.onClose();
    context.pushNamed(RouteNames.settings);
  }

  void _openHistory() {
    widget.onClose();
    context.pushNamed(RouteNames.history);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: colors.drawerBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: SvgPicture.asset('assets/images/typography.svg')),
            InkWell(
              onTap: _openHistory,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.drawerRecentSection,
                      style: AppTextStyles.body(
                          fontSize: 13, color: colors.ink600),
                    ),
                    const SizedBox(width: 4),
                    AppIcon(AppIconShape.arrowUpRight,
                        size: 11, color: colors.ink600),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildRecentList(colors, l10n)),
            _DrawerFooter(onNewChat: _newChat, onSettingsTap: _openSettings),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList(AppColors colors, AppLocalizations l10n) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.historyErrorMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(fontSize: 13, color: colors.ink600),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: refresh,
                child: Text(
                  l10n.historyRetryButton,
                  style: AppTextStyles.body(
                      fontSize: 13, color: colors.accentBright),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final sessions = _sessions!;
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Text(
            l10n.historyEmptyMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 13, color: colors.ink600),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            session.title ?? l10n.historyUntitledSession,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(fontSize: 16, color: colors.ink),
          ),
        );
      },
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.onNewChat, required this.onSettingsTap});

  final VoidCallback onNewChat;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleIconButton(
            onTap: onSettingsTap,
            tooltip: l10n.commonSettings,
            child: SvgPicture.asset('assets/images/setting.svg'),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onNewChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.chatSendButton,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/images/plus.svg'),
                  const SizedBox(width: 10),
                  Text(l10n.chatNewTooltip,
                      style: AppTextStyles.body(
                              fontSize: 15, color: colors.ink, height: 1.6)
                          .copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.onTap,
    required this.tooltip,
    required this.child,
  });

  final VoidCallback onTap;
  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: colors.surfaceMuted, shape: BoxShape.circle),
          child: child,
        ),
      ),
    );
  }
}
