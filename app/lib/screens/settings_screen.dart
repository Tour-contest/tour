import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/auth_service.dart';
import 'package:nullnull/data/connectivity_service.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/data/logout_service.dart';
import 'package:nullnull/data/user_profile_storage.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/screens/web_view_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_locale_controller.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/confirm_dialog.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';
import 'package:nullnull/widgets/nullnull/profile_avatar.dart';

/// SNS 로그인 수단의 화면 표시명. 다국어 대응을 위해 [SnsProvider] 자체에는
/// 문자열을 두지 않고 여기서 [AppLocalizations]로 매핑한다.
String _providerLabel(AppLocalizations l10n, SnsProvider provider) =>
    switch (provider) {
      SnsProvider.kakao => l10n.snsProviderKakao,
    };

/// 실제 이메일(카카오 로그인으로 받아온 값)을 그대로 노출하지 않도록 `@` 바로
/// 앞 최대 3글자를 `*`로 가린다(예: `hie2gw@gmail.com` → `hie***@gmail.com`).
/// 로컬 파트가 3글자 이하면 전부 가린다. `DemoUser`의 목업 이메일은 이미 자체
/// 마스킹 포맷(`travel****@kakao.com`)이라 이 함수를 거치지 않는다.
String _maskEmail(String email) {
  final atIndex = email.indexOf('@');
  if (atIndex <= 0) return email;
  final local = email.substring(0, atIndex);
  final domain = email.substring(atIndex);
  final maskLength = local.length <= 3 ? local.length : 3;
  final visible = local.substring(0, local.length - maskLength);
  return '$visible${'*' * maskLength}$domain';
}

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
      AppLocaleOption.korean => l10n.languageOptionKorean,
      AppLocaleOption.english => l10n.languageOptionEnglish,
    };

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 프로토타입 단계라 실제 로그인 세션이 없고, 지원하는 SNS 로그인 수단도
  // 카카오 하나뿐이라 항상 이 값으로 고정한다("최근 로그인" 수단 저장 기능은
  // 삭제됨).
  final SnsProvider _provider = SnsProvider.kakao;

  // 카카오 로그인 성공 시 받아와 저장해둔 실제 닉네임/프로필 사진(`login_screen.dart`
  // `_saveKakaoProfile`). 없으면(동의 안 함, 조회 실패 등) `_ProfileSummary`가
  // `DemoUser` 목업으로 대체한다.
  UserProfile? _profile;

  /// 로그아웃 요청(`LogoutService.logout`) 진행 중에는 화면 터치를 막고
  /// 로딩 인디케이터를 보여준다(`login_screen.dart`의 `_isLoggingIn`과 동일한
  /// `PopScope` + `Stack`/`ColoredBox` 오버레이 패턴).
  bool _isLoggingOut = false;

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

  Future<void> _contactByEmail(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: AppInfo.developerEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsContactCopied)),
    );
  }

  void _openWebView(BuildContext context,
      {required String title, required String url}) {
    context.pushNamed(
      RouteNames.webView,
      extra: WebViewRouteArgs(title: title, url: url),
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
      builder: (_) => ConfirmDialog(
        title: l10n.settingsDisconnectDialogTitle,
        message: l10n
            .settingsDisconnectDialogMessage(_providerLabel(l10n, _provider)),
        confirmLabel: l10n.settingsDisconnect,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final disconnected = await _disconnectKakao(context);
    if (!disconnected || !context.mounted) return;
    context.goNamed(RouteNames.login);
  }

  /// `DELETE /api/v1/me`(`AuthService.withdraw()`)로 회원 탈퇴를 요청한다.
  /// `docs/API_SPEC.md`에 이 엔드포인트가 카카오 연결 해제까지 함께 처리한다고
  /// 명시돼 있어, 클라이언트에서 별도로 `UserApi.instance.unlink()`를 부르지
  /// 않는다. 성공하면 로컬 프로필도 함께 지운다.
  Future<bool> _disconnectKakao(BuildContext context) async {
    try {
      await AuthService.withdraw();
      await UserProfileStorage.clear();
      AppLog.logger.i('회원 탈퇴 성공');
      return true;
    } catch (error) {
      AppLog.logger.e('회원 탈퇴 실패', error: error);
      if (!context.mounted) return false;
      if (!await ConnectivityService().isOnline()) return false;
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.settingsDisconnectError)),
      );
      return false;
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: l10n.settingsLogoutDialogTitle,
        message: l10n.settingsLogoutDialogMessage,
        confirmLabel: l10n.settingsLogout,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() => _isLoggingOut = true);
    await LogoutService.logout(_provider);
    if (!context.mounted) return;
    context.goNamed(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_isLoggingOut,
      child: Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  PlainHeader(title: l10n.commonSettings),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      children: [
                        _SectionLabel(l10n.settingsSectionMyInfo),
                        _ProfileSummary(
                          provider: _provider,
                          nickname: _profile?.nickname,
                          profileImageUrl: _profile?.profileImageUrl,
                        ),
                        const SizedBox(height: 8),
                        _SettingsRow(
                          label: l10n.settingsEmailLabel,
                          trailingText: _profile?.email != null
                              ? _maskEmail(_profile!.email!)
                              : DemoUser.maskedEmailFor(_provider),
                          isFirst: true,
                        ),
                        _ConnectedAccountRow(
                          provider: _provider,
                          enabled: !(_profile?.isAdmin ?? false),
                          onDisconnect: () => _confirmDisconnect(context),
                        ),
                        // const SizedBox(height: 28),
                        // _SectionLabel(l10n.settingsSectionFontSize),
                        // ValueListenableBuilder<AppFontScale>(
                        //   valueListenable: appTextScaleController,
                        //   builder: (context, scale, _) {
                        //     return Column(
                        //       children: [
                        //         for (final option in AppFontScale.values)
                        //           _RadioRow(
                        //             label: _fontScaleLabel(l10n, option),
                        //             selected: scale == option,
                        //             onTap: () =>
                        //                 appTextScaleController.setScale(option),
                        //             isFirst: option == AppFontScale.values.first,
                        //           ),
                        //       ],
                        //     );
                        //   },
                        // ),
                        // const SizedBox(height: 28),
                        // _SectionLabel(l10n.settingsSectionLanguage),
                        // ValueListenableBuilder<AppLocaleOption>(
                        //   valueListenable: appLocaleController,
                        //   builder: (context, option, _) {
                        //     return Column(
                        //       children: [
                        //         for (final value in AppLocaleOption.values)
                        //           _RadioRow(
                        //             label: _languageOptionLabel(l10n, value),
                        //             selected: option == value,
                        //             onTap: () => appLocaleController.setOption(value),
                        //             isFirst: value == AppLocaleOption.values.first,
                        //           ),
                        //       ],
                        //     );
                        //   },
                        // ),
                        const SizedBox(height: 28),
                        _SectionLabel(l10n.settingsSectionInfo),
                        _SettingsRow(
                          label: l10n.settingsAppVersion,
                          trailingText:
                              '${AppInfo.package.version} (${AppInfo.package.buildNumber})',
                          isFirst: true,
                        ),
                        _SettingsRow(
                          label: l10n.settingsPrivacyPolicy,
                          onTap: () => _openWebView(
                            context,
                            title: l10n.settingsPrivacyPolicy,
                            url: AppInfo.privacyPolicyUrl,
                          ),
                        ),
                        _SettingsRow(
                          label: l10n.settingsTermsOfService,
                          onTap: () => _openWebView(
                            context,
                            title: l10n.settingsTermsOfService,
                            url: AppInfo.termsOfServiceUrl,
                          ),
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
              if (_isLoggingOut)
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
            fontSize: 11, color: colors.accentBright, letterSpacing: 1.8),
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
                    color: selected ? colors.accent : colors.divider,
                    width: 1.4),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: colors.accent),
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
              AppIcon(AppIconShape.arrowUpRight,
                  size: 12, color: colors.accent),
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
    };

/// "연결된 계정" 표시에 쓰는 작은 SNS 아이콘 색. `login_screen.dart`의 로그인
/// 버튼과 같은 브랜드 컬러(`AppColors`의 `kakaoContainer`(카카오 노란색))를
/// 그대로 쓴다 — 이전에는 앱 공통 `colors.accent`(골드)였다.
Color _snsIconColor(AppColors colors, SnsProvider provider) =>
    switch (provider) {
      SnsProvider.kakao => colors.kakaoContainer,
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

/// "연결된 계정" 행. 회원 탈퇴 버튼 탭 시 확인 팝업을 띄운다. [enabled]가
/// `false`(관리자 로그인 계정, `UserProfile.isAdmin`)면 버튼을 회색으로
/// 비활성화하고 탭 자체를 막는다 — 관리자는 카카오 연결 해제를 함께 처리하는
/// `DELETE /api/v1/me` 탈퇴 흐름의 대상이 아니기 때문.
class _ConnectedAccountRow extends StatelessWidget {
  const _ConnectedAccountRow({
    required this.provider,
    required this.enabled,
    required this.onDisconnect,
  });

  final SnsProvider provider;
  final bool enabled;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final buttonLabel = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: enabled ? colors.accent : colors.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.settingsDisconnect,
        style: AppTextStyles.body(
            fontSize: 11.5,
            color: enabled ? colors.accentBright : colors.ink600),
      ),
    );
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
          _SnsIcon(
              provider: provider,
              size: 14,
              color: _snsIconColor(colors, provider)),
          const SizedBox(width: 6),
          Text(
            l10n.settingsAccountSuffix(_providerLabel(l10n, provider)),
            style: AppTextStyles.body(fontSize: 12.5, color: colors.ink600),
          ),
          const SizedBox(width: 10),
          if (enabled)
            InkWell(
              onTap: onDisconnect,
              borderRadius: BorderRadius.circular(4),
              child: buttonLabel,
            )
          else
            Tooltip(
              message: l10n.settingsDisconnectAdminDisabledTooltip,
              child: buttonLabel,
            ),
        ],
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
          overlayColor: colors.accentTint08,
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
  const _ProfileSummary({
    required this.provider,
    this.nickname,
    this.profileImageUrl,
  });

  final SnsProvider provider;

  /// 로그인 시 받아온 실제 닉네임/프로필 사진. `null`이면 `DemoUser` 목업으로
  /// 대체한다(카카오 동의 안 함, 조회 실패 등).
  final String? nickname;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final displayName = nickname ??
        DemoUser.nicknameFor(
            provider, Localizations.localeOf(context).languageCode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          ProfileAvatar(
            size: 46,
            imageUrl: profileImageUrl,
            initial: displayName.substring(0, 1),
            borderColor: colors.accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style:
                        AppTextStyles.heading(fontSize: 17, color: colors.ink)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _SnsIcon(
                        provider: provider,
                        size: 12,
                        color: _snsIconColor(colors, provider)),
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
