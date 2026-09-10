import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// docs/assets/images/drawer_screen.png 시안: 로고, "최근" 대화 목록, 하단
/// 설정 원형 버튼 + "새 채팅" pill 버튼으로 구성된 드로어. `PushDrawer`(오버레이가
/// 아닌 본문을 밀어내는 방식)의 `drawer` 슬롯에 들어가므로, 항목을 고르거나
/// 닫기를 원할 때 `Navigator.pop`이 아니라 [onClose]로 직접 닫아야 한다.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key, required this.onNewChat, required this.onClose});

  final VoidCallback onNewChat;
  final VoidCallback onClose;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late List<HistoryEntry> _entries;
  String? _loadedForLanguageCode;

  void _newChat() {
    widget.onNewChat();
    widget.onClose();
  }

  void _openSettings() {
    widget.onClose();
    context.pushNamed(RouteNames.settings);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_loadedForLanguageCode != languageCode) {
      _entries = List.of(historyEntriesFor(languageCode));
      _loadedForLanguageCode = languageCode;
    }

    return Drawer(
      backgroundColor: colors.drawerBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                child: SvgPicture.asset('assets/images/typography.svg')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.drawerRecentSection,
                style: AppTextStyles.body(fontSize: 13, color: colors.ink600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.body(fontSize: 16, color: colors.ink),
                    ),
                  );
                },
              ),
            ),
            _DrawerFooter(onNewChat: _newChat, onSettingsTap: _openSettings),
          ],
        ),
      ),
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
