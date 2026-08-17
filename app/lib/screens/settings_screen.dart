import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _contactByEmail(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: AppInfo.developerEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('클립보드에 복사되었습니다.')),
    );
  }

  void _openLicenses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LicensePage(
          applicationName: AppInfo.serviceName,
          applicationVersion: AppInfo.package.version,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: '설정',
              leading: IconButton(
                icon: AppIcon(AppIconShape.chevronLeft,
                    size: 18, color: colors.ink),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '뒤로',
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _SectionLabel('화면 모드'),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: appThemeController,
                    builder: (context, mode, _) {
                      return Column(
                        children: [
                          _ThemeModeRow(
                            label: '시스템 설정 사용',
                            selected: mode == ThemeMode.system,
                            onTap: () => appThemeController
                                .setThemeMode(ThemeMode.system),
                            isFirst: true,
                          ),
                          _ThemeModeRow(
                            label: '라이트 모드',
                            selected: mode == ThemeMode.light,
                            onTap: () => appThemeController
                                .setThemeMode(ThemeMode.light),
                          ),
                          _ThemeModeRow(
                            label: '다크 모드',
                            selected: mode == ThemeMode.dark,
                            onTap: () =>
                                appThemeController.setThemeMode(ThemeMode.dark),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('정보'),
                  _SettingsRow(
                    label: '앱 버전',
                    trailingText:
                        '${AppInfo.package.version} (${AppInfo.package.buildNumber})',
                    isFirst: true,
                  ),
                  _SettingsRow(
                    label: '문의하기',
                    trailingText: AppInfo.developerEmail,
                    onTap: () => _contactByEmail(context),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('오픈소스'),
                  _SettingsRow(
                    label: '오픈소스 라이선스',
                    onTap: () => _openLicenses(context),
                    isFirst: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      child: Text(
        text,
        style: AppTextStyles.body(
            fontSize: 11, color: colors.gold700, letterSpacing: 1.8),
      ),
    );
  }
}

class _ThemeModeRow extends StatelessWidget {
  const _ThemeModeRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isFirst = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: isFirst ? BorderSide.none : BorderSide(color: colors.divider),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body(fontSize: 14, color: colors.ink)),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? colors.gold : colors.divider, width: 1.4),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: colors.gold),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.trailingText,
    this.onTap,
    this.isFirst = false,
  });

  final String label;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: isFirst ? BorderSide.none : BorderSide(color: colors.divider),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body(fontSize: 14, color: colors.ink)),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 12),
              Text(
                trailingText!,
                style: AppTextStyles.body(fontSize: 12.5, color: colors.ink600),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 8),
              AppIcon(AppIconShape.arrowUpRight, size: 12, color: colors.gold),
            ],
          ],
        ),
      ),
    );
  }
}
