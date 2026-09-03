import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_locale_controller.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// SNS 로그인 수단의 화면 표시명. 다국어 대응을 위해 [SnsProvider] 자체에는
/// 문자열을 두지 않고 여기서 [AppLocalizations]로 매핑한다.
String _providerLabel(AppLocalizations l10n, SnsProvider provider) =>
    switch (provider) {
      SnsProvider.kakao => l10n.snsProviderKakao,
      SnsProvider.naver => l10n.snsProviderNaver,
    };

/// 글자 크기 단계의 화면 표시명. [AppFontScale] 자체에는 다국어 대응을 위해
/// 문자열을 두지 않고 여기서 매핑한다.
String _fontScaleLabel(AppLocalizations l10n, AppFontScale scale) =>
    switch (scale) {
      AppFontScale.small => l10n.fontScaleSmall,
      AppFontScale.normal => l10n.fontScaleNormal,
      AppFontScale.large => l10n.fontScaleLarge,
      AppFontScale.extraLarge => l10n.fontScaleExtraLarge,
    };

/// 언어 옵션의 화면 표시명. [AppLocaleOption] 자체에는 다국어 대응을 위해
/// 문자열을 두지 않고 여기서 매핑한다.
String _languageOptionLabel(AppLocalizations l10n, AppLocaleOption option) =>
    switch (option) {
      AppLocaleOption.system => l10n.languageOptionSystem,
      AppLocaleOption.korean => l10n.languageOptionKorean,
      AppLocaleOption.english => l10n.languageOptionEnglish,
    };

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
      SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsContactCopied)),
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

  Future<void> _confirmDisconnect(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: l10n.settingsDisconnectDialogTitle,
        message: l10n
            .settingsDisconnectDialogMessage(_providerLabel(l10n, _provider)),
        confirmLabel: l10n.settingsDisconnect,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.settingsDisconnectSnackbar)),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: l10n.settingsLogoutDialogTitle,
        message: l10n.settingsLogoutDialogMessage,
        confirmLabel: l10n.settingsLogout,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.goNamed(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: l10n.commonSettings,
              leading: IconButton(
                icon: AppIcon(AppIconShape.chevronLeft,
                    size: 18, color: colors.ink),
                onPressed: () => context.pop(),
                tooltip: l10n.commonBack,
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _SectionLabel(l10n.settingsSectionMyInfo),
                  _ProfileSummary(provider: _provider),
                  const SizedBox(height: 8),
                  _SettingsRow(
                    label: l10n.settingsEmailLabel,
                    trailingText: DemoUser.maskedEmailFor(_provider),
                    isFirst: true,
                  ),
                  _ConnectedAccountRow(
                    provider: _provider,
                    onDisconnect: () => _confirmDisconnect(context),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel(l10n.settingsSectionFontSize),
                  ValueListenableBuilder<AppFontScale>(
                    valueListenable: appTextScaleController,
                    builder: (context, scale, _) {
                      return Column(
                        children: [
                          for (final option in AppFontScale.values)
                            _RadioRow(
                              label: _fontScaleLabel(l10n, option),
                              selected: scale == option,
                              onTap: () =>
                                  appTextScaleController.setScale(option),
                              isFirst: option == AppFontScale.values.first,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel(l10n.settingsSectionLanguage),
                  ValueListenableBuilder<AppLocaleOption>(
                    valueListenable: appLocaleController,
                    builder: (context, option, _) {
                      return Column(
                        children: [
                          for (final value in AppLocaleOption.values)
                            _RadioRow(
                              label: _languageOptionLabel(l10n, value),
                              selected: option == value,
                              onTap: () => appLocaleController.setOption(value),
                              isFirst: value == AppLocaleOption.values.first,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel(l10n.settingsSectionInfo),
                  _SettingsRow(
                    label: l10n.settingsAppVersion,
                    trailingText:
                        '${AppInfo.package.version} (${AppInfo.package.buildNumber})',
                    isFirst: true,
                  ),
                  _SettingsRow(
                    label: l10n.settingsContact,
                    trailingText: AppInfo.developerEmail,
                    onTap: () => _contactByEmail(context),
                  ),
                  const SizedBox(height: 28),
                  _SectionLabel(l10n.settingsSectionOpenSource),
                  _SettingsRow(
                    label: l10n.settingsOpenSourceLicense,
                    onTap: () => _openLicenses(context),
                    isFirst: true,
                  ),
                  const SizedBox(height: 28),
                  _LogoutButton(onTap: () => _confirmLogout(context)),
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

/// SNS 로그인 수단을 SVG 에셋 경로로 매핑한다(`app_icon.dart` 폐기 진행 중이라
/// `AppIconShape` 대신 `assets/images/` SVG를 사용).
String _snsAssetFor(SnsProvider provider) => switch (provider) {
      SnsProvider.kakao => 'assets/images/icon_kakao_login.svg',
      SnsProvider.naver => 'assets/images/icon_naver_login.svg',
    };

class _SnsIcon extends StatelessWidget {
  const _SnsIcon(
      {required this.provider, required this.size, required this.color});

  final SnsProvider provider;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        _snsAssetFor(provider),
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

/// "연결된 계정" 행. 연결 끊기 버튼 탭 시 확인 팝업을 띄운다.
class _ConnectedAccountRow extends StatelessWidget {
  const _ConnectedAccountRow({
    required this.provider,
    required this.onDisconnect,
  });

  final SnsProvider provider;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.settingsConnectedAccount,
                style: AppTextStyles.body(fontSize: 14, color: colors.ink)),
          ),
          _SnsIcon(provider: provider, size: 14, color: colors.gold),
          const SizedBox(width: 6),
          Text(
            l10n.settingsAccountSuffix(_providerLabel(l10n, provider)),
            style: AppTextStyles.body(fontSize: 12.5, color: colors.ink600),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onDisconnect,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: colors.gold),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.settingsDisconnect,
                style:
                    AppTextStyles.body(fontSize: 11.5, color: colors.gold700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2버튼(취소 / 확인) 확인 팝업. "연결 끊기"·"로그아웃"처럼 제목·설명·확인
/// 버튼 문구만 다른 확인 다이얼로그에서 공용으로 사용한다.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading(fontSize: 17, color: colors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                  fontSize: 12.5, color: colors.ink700, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: AppLocalizations.of(context)!.commonCancel,
                    filled: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: confirmLabel,
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? colors.gold : null,
          side: BorderSide(color: colors.gold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          overlayColor: colors.goldTint08,
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 13.5,
            color: filled ? colors.paper : colors.gold700,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          overlayColor: colors.goldTint08,
        ),
        child: Text(
          AppLocalizations.of(context)!.settingsLogout,
          style: AppTextStyles.body(fontSize: 14, color: colors.ink700),
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.provider});

  final SnsProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final nickname = DemoUser.nicknameFor(
        provider, Localizations.localeOf(context).languageCode);
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
                    _SnsIcon(provider: provider, size: 12, color: colors.gold),
                    const SizedBox(width: 5),
                    Text(
                      l10n.settingsLoggedInWith(_providerLabel(l10n, provider)),
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
