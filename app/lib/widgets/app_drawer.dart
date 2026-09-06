import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key, required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late List<HistoryEntry> _entries;
  String? _loadedForLanguageCode;
  SnsProvider _provider = SnsProvider.kakao;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final provider = await LoginPreference.readLastProvider();
    if (!mounted || provider == null) return;
    setState(() => _provider = provider);
  }

  void _newChat() {
    widget.onNewChat();
    Navigator.of(context).pop();
  }

  void _openSettings() {
    Navigator.of(context).pop();
    context.pushNamed(RouteNames.settings);
  }

  void _delete(HistoryEntry entry) {
    setState(() => _entries.remove(entry));
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
    final nickname = DemoUser.nicknameFor(_provider, languageCode);

    return Drawer(
      backgroundColor: colors.drawerBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Text('널널',
                  style:
                      AppTextStyles.heading(fontSize: 17, color: colors.ink)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _newChat,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      AppIcon(AppIconShape.edit, size: 15, color: colors.ink),
                      const SizedBox(width: 10),
                      Text(l10n.chatNewTooltip,
                          style: AppTextStyles.body(
                              fontSize: 13.5, color: colors.ink)),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                l10n.drawerRecentSection,
                style: AppTextStyles.body(
                    fontSize: 11, color: colors.ink600, letterSpacing: 1.4),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final active = index == 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? colors.surfaceMuted : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                    fontSize: 13, color: colors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.date,
                                style: AppTextStyles.tabularNums(
                                  AppTextStyles.body(
                                      fontSize: 10.5, color: colors.ink600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (active)
                          InkWell(
                            onTap: () => _delete(entry),
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text('✕',
                                  style: AppTextStyles.body(
                                      fontSize: 12, color: colors.ink600)),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _ProfileFooter(
                nickname: nickname,
                onSettingsTap: _openSettings,
                colors: colors),
          ],
        ),
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter({
    required this.nickname,
    required this.onSettingsTap,
    required this.colors,
  });

  final String nickname;
  final VoidCallback onSettingsTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.accent),
            ),
            child: Text(
              nickname.substring(0, 1),
              style: AppTextStyles.heading(
                  fontSize: 14, color: colors.accentBright),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(fontSize: 13, color: colors.ink),
            ),
          ),
          IconButton(
            icon:
                AppIcon(AppIconShape.settings, size: 17, color: colors.ink600),
            onPressed: onSettingsTap,
            tooltip: l10n.commonSettings,
          ),
        ],
      ),
    );
  }
}
