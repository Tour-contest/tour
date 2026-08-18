import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 프로토타입 단계라 실제 로그인 세션이 없으므로, 로그인 화면에서 저장한
  // 마지막 SNS 로그인 수단을 로그인된 계정으로 간주한다. 저장된 값이 없으면
  // 카카오로 로그인했다고 가정한다.
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
                  _SectionLabel('내 정보'),
                  _ProfileSummary(provider: _provider),
                  const SizedBox(height: 8),
                  _SettingsRow(
                    label: '이메일',
                    trailingText: DemoUser.maskedEmailFor(_provider),
                    isFirst: true,
                  ),
                  _SettingsRow(
                    label: '연결된 계정',
                    trailingIcon: _iconFor(_provider),
                    trailingText: '${_provider.label} 계정',
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel('글자 크기'),
                  ValueListenableBuilder<AppFontScale>(
                    valueListenable: appTextScaleController,
                    builder: (context, scale, _) {
                      return Column(
                        children: [
                          for (final option in AppFontScale.values)
                            _RadioRow(
                              label: option.label,
                              selected: scale == option,
                              onTap: () =>
                                  appTextScaleController.setScale(option),
                              isFirst: option == AppFontScale.values.first,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '오늘은 어디로 여행을 떠나볼까요?',
                    style: AppTextStyles.body(fontSize: 14, color: colors.ink700),
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

class _RadioRow extends StatelessWidget {
  const _RadioRow({
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
    this.trailingIcon,
    this.onTap,
    this.isFirst = false,
  });

  final String label;
  final String? trailingText;
  final AppIconShape? trailingIcon;
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
            if (trailingIcon != null) ...[
              AppIcon(trailingIcon!, size: 14, color: colors.gold),
              const SizedBox(width: 6),
            ],
            if (trailingText != null) ...[
              const SizedBox(width: 6),
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

/// 로그인 화면에서 사용한 SNS 로그인 수단을 아이콘으로 매핑한다.
AppIconShape _iconFor(SnsProvider provider) => switch (provider) {
      SnsProvider.kakao => AppIconShape.kakao,
      SnsProvider.naver => AppIconShape.naver,
    };

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.provider});

  final SnsProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final nickname = DemoUser.nicknameFor(provider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.gold),
            ),
            child: Text(
              nickname.substring(0, 1),
              style: AppTextStyles.heading(color: colors.gold700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname,
                    style:
                        AppTextStyles.heading(fontSize: 17, color: colors.ink)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppIcon(_iconFor(provider), size: 12, color: colors.gold),
                    const SizedBox(width: 5),
                    Text(
                      '${provider.label} 계정으로 로그인 중',
                      style: AppTextStyles.body(
                          fontSize: 11.5, color: colors.ink600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
