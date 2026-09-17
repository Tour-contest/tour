import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/auth_service.dart';
import 'package:nullnull/data/connectivity_service.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/data/user_profile_storage.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/confirm_dialog.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';

/// 온보딩 다음에 노출되는 로그인 화면. SNS 로그인만으로 로그인/회원가입을 함께
/// 처리한다. 카카오는 `kakao_flutter_sdk_user`로 실제 로그인을 수행한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  ///  진행 중에는 화면 터치·뒤로가기를 막는다.
  bool _isLoggingIn = false;

  /// [provider]가 `null`이면 관리자 로그인처럼 SNS 제공자가 없는 로그인
  /// 수단이라는 뜻으로, 이 경우 `logLogin` 애널리틱스 이벤트는 건너뛴다.
  Future<void> _completeLogin(SnsProvider? provider) async {
    if (provider != null) unawaited(AnalyticsService.logLogin(provider));
    if (!mounted) return;
    context.goNamed(RouteNames.chat);
  }

  Future<void> _loginWithKakao() async {
    setState(() => _isLoggingIn = true);
    try {
      final installed = await isKakaoTalkInstalled();
      OAuthToken token;
      if (installed) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') return;
          AppLog.logger.w('카카오톡 앱 로그인 실패, 계정 로그인 전환 여부 확인', error: error);
          if (!mounted) return;
          // 다이얼로그를 띄우는 동안은 전체 화면 로딩 오버레이를 내려 두 겹으로
          // 보이지 않게 한다 — 계정 로그인으로 전환하면 다시 켠다.
          setState(() => _isLoggingIn = false);
          if (!mounted) return;
          final useAccountLogin = await _confirmKakaoAccountFallback();
          if (useAccountLogin != true || !mounted) return;
          setState(() => _isLoggingIn = true);
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      AppLog.logger.i('카카오 로그인 성공, 백엔드 토큰 교환 시작');
      await AuthService.loginWithKakao(token.accessToken);
      await _saveKakaoProfile();
      await _completeLogin(SnsProvider.kakao);
    } catch (error) {
      if (error is PlatformException && error.code == 'CANCELED') return;
      AppLog.logger.e('카카오 로그인 실패', error: error);
      if (!mounted) return;
      // 오프라인 상태면 전역 오프라인 다이얼로그(NetworkStatusListener)가 이미 화면
      // 전체를 덮고 안내 중이라, 이 토스트는 다이얼로그 뒤에 가려 안 보인 채로
      // 사라진다. 그런 경우는 중복 안내를 띄우지 않는다.
      if (!await ConnectivityService().isOnline()) return;
      if (!mounted) return;
      AppToast.show(
        AppLocalizations.of(context)!.loginKakaoError,
        type: AppToastType.info,
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  /// 카카오톡 앱 설치 상태에서 [UserApi.instance.loginWithKakaoTalk]이 취소가
  /// 아닌 에러로 실패했을 때(예: 기기에 카카오톡은 설치돼 있지만 로그인은
  /// 안 돼 있는 경우) [UserApi.instance.loginWithKakaoAccount](웹 기반 계정
  /// 로그인)로 전환할지 묻는 확인 팝업. `ConfirmDialog`와 같은 톤을 쓴다.
  Future<bool?> _confirmKakaoAccountFallback() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: l10n.loginKakaoTalkFailedDialogTitle,
        message: l10n.loginKakaoTalkFailedDialogMessage,
        confirmLabel: l10n.loginKakaoTalkFailedDialogConfirm,
      ),
    );
  }

  /// 카카오 `me()`로 닉네임/프로필 사진 URL/이메일을 받아와 [UserProfileStorage]에
  /// 저장한다(`settings_screen.dart`의 "내 정보"가 이 값을 읽어 보여준다).
  /// 닉네임/프로필 사진은 `kakaoAccount.profile`, 이메일은 `kakaoAccount.email`에
  /// 있다. 동의하지 않은 항목은 `null`로 오며, 그 경우 저장하는 쪽에서 걸러내
  /// 읽는 쪽이 `DemoUser` 목업으로 대체하게 둔다. 로그인 자체는 이미
  /// 성공했으므로 이 조회가 실패해도 무시하고 로그인 플로우는 계속 진행한다.
  Future<void> _saveKakaoProfile() async {
    try {
      final user = await UserApi.instance.me();
      AppLog.logger.i('카카오 me() 응답: $user');
      final account = user.kakaoAccount;
      await UserProfileStorage.save(
        nickname: account?.profile?.nickname,
        profileImageUrl: account?.profile?.profileImageUrl,
        email: account?.email,
      );
    } catch (error) {
      AppLog.logger.e('카카오 me() 조회 실패', error: error);
    }
  }

  /// 하단 카드 안쪽 여백에 쓸 최소 바닥 여백. iOS는 홈 인디케이터 때문에
  /// `MediaQuery.paddingOf(context).bottom`이 항상 0보다 크지만, 안드로이드는
  /// 제스처 내비게이션이어도 이 값이 실기기/에뮬레이터에서 0으로 오는 경우가
  /// 있어(라이브로 확인함 — 버튼이 화면 맨 아래에 여백 없이 붙어 보임)
  /// 시스템 인셋과 별개로 최소 여백을 보장한다.
  static const double _minBottomCardPadding = 24;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final systemBottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomCardPadding = systemBottomPadding > _minBottomCardPadding
        ? systemBottomPadding
        : _minBottomCardPadding;
    final screen = PopScope(
      canPop: !_isLoggingIn,
      child: Scaffold(
        backgroundColor: colors.loginBackground,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.loginBackgroundGlow, colors.loginBackground],
              stops: const [0, 0.55],
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(26, 27, 26, 0),
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      colors.loginHeadlineGradientStart,
                                      colors.loginHeadlineGradientMid,
                                      colors.loginHeadlineGradientEnd,
                                    ],
                                    stops: const [0, 0.399, 1],
                                  ).createShader(bounds),
                                  child: Text(
                                    l10n.loginGradientHeadline,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.heading(
                                      fontSize: 28,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.5,
                                    ).copyWith(letterSpacing: 0.56),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  l10n.loginSubheadline,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.heading(
                                    fontSize: 15,
                                    weight: FontWeight.w600,
                                    color: colors.loginSubheadline,
                                    height: 1.5,
                                  ).copyWith(letterSpacing: 0.3),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 40),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.accent.withAlpha(115),
                                        blurRadius: 44,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Mascot(size: 130),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      37,
                      20,
                      bottomCardPadding,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      border: Border(
                        top: BorderSide(
                            color: colors.loginHeadlineGradientMid, width: 1.5),
                        left: BorderSide(
                            color: colors.loginHeadlineGradientMid, width: 1.5),
                        right: BorderSide(
                            color: colors.loginHeadlineGradientMid, width: 1.5),
                      ),
                      color: colors.loginBackground.withValues(alpha: 0.1),
                      // color: Color(0x21A3F1F9),
                      // gradient: LinearGradient(
                      //   begin: Alignment.topCenter,
                      //   end: Alignment.bottomCenter,
                      //   colors: [
                      //     colors.loginBottomBarGradientStart,
                      //     colors.loginBottomBarGradientMid,
                      //     colors.loginBottomBarGradientEnd,
                      //   ],
                      //   stops: const [0, 0.399, 1],
                      // ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.loginBottomBarGradientMid,
                          // offset: const Offset(5, 4),
                          blurRadius: 4,
                          blurStyle: BlurStyle.inner,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.loginInviteCaption,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading(
                              weight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 36),
                        _SnsLoginButton(
                          icon: SvgPicture.asset(
                            'assets/images/icon_kakao_login.svg',
                            colorFilter: ColorFilter.mode(
                                colors.kakaoSymbol, BlendMode.srcIn),
                          ),
                          label: l10n.loginKakaoButton,
                          onTap: _isLoggingIn ? null : _loginWithKakao,
                          backgroundColor: colors.kakaoContainer,
                          labelColor: colors.kakaoLabel,
                        ),
                        const SizedBox(height: 14),
                        _AdminLoginEntry(
                          enabled: !_isLoggingIn,
                          onSuccess: () => _completeLogin(null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isLoggingIn)
                ColoredBox(
                  color: colors.scrim,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
    // 사용자 요청으로 로그인 화면의 텍스트는 접근성 글자 크기 설정과 무관하게
    // 항상 기본 크기로 고정한다 — 개별 `Text`마다 `textScaler`를 주는 대신
    // 화면 전체를 감싸는 `MediaQuery`로 한 번에 덮어쓴다. `showDialog`로 뜨는
    // `_AdminLoginDialog`/`ConfirmDialog`(카카오 계정 로그인 전환 확인)는 앱
    // 루트 Navigator의 오버레이에 별도로 올라가 이 트리 바깥이라 영향받지
    // 않는다(필요하면 별도로 고정해야 함).
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: screen,
    );
  }
}

class _SnsLoginButton extends StatelessWidget {
  const _SnsLoginButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.labelColor,
  });

  static const double _width = 240;
  static const double _height = 48;
  static const double _borderRadius = 12;
  static const double _iconGap = 12;

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  /// 각 SNS 브랜드 가이드에 따른 버튼 채움 색.
  final Color backgroundColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: _width,
      height: _height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius)),
          padding: EdgeInsets.zero,
          overlayColor: colors.accentTint08,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: _iconGap),
            Text(
              label,
              style: AppTextStyles.heading(
                  fontSize: 14, weight: FontWeight.w600, color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카카오 버튼 아래에 있는 숨겨진 관리자 로그인 진입점. 일반 사용자 눈에는
/// 잘 띄지 않도록 아주 작은 글자·낮은 대비(카드 배경에 가까운 색)로 그리되,
/// 탭 영역은 접근성을 위해 텍스트보다 넉넉하게 잡는다.
class _AdminLoginEntry extends StatelessWidget {
  const _AdminLoginEntry({required this.enabled, required this.onSuccess});

  final bool enabled;
  final VoidCallback onSuccess;

  Future<void> _open(BuildContext context) async {
    final success = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdminLoginDialog(),
    );
    if (success == true) onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _open(context) : null,
        child: Text(
          l10n.loginAdminEntryLabel,
          style: AppTextStyles.body(
            fontSize: 14,
            color: colors.loginSubheadline,
          ),
        ),
      ),
    );
  }
}

/// [_AdminLoginEntry] 탭 시 뜨는 아이디/비밀번호 입력 팝업. 성공하면
/// `Navigator.pop(context, true)`로 닫혀 [_AdminLoginEntry]가 로그인 완료
/// 처리를 이어받는다. `ConfirmDialog`와 같은 톤(배경 `colors.graphite`,
/// 테두리 `colors.inputBarBorder`, 모서리 16)을 따른다.
class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context)!;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = l10n.loginAdminValidationError);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await AuthService.loginAdmin(username, password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      AppLog.logger.e('관리자 로그인 실패', error: error);
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      AppLog.logger.e('관리자 로그인 실패', error: error);
      if (!mounted) return;
      setState(() => _errorMessage = l10n.loginAdminError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: colors.graphite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.inputBarBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.loginAdminDialogTitle,
              style: AppTextStyles.heading(fontSize: 17, color: colors.ink),
            ),
            const SizedBox(height: 20),
            _AdminTextField(
              controller: _usernameController,
              label: l10n.loginAdminUsernameLabel,
              obscureText: false,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            _AdminTextField(
              controller: _passwordController,
              label: l10n.loginAdminPasswordLabel,
              obscureText: true,
              enabled: !_isSubmitting,
              onSubmitted: (_) => _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                    AppTextStyles.body(fontSize: 12.5, color: colors.busyText),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _AdminDialogButton(
                    label: l10n.commonCancel,
                    filled: false,
                    onTap: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminDialogButton(
                    label: l10n.loginAdminSubmitButton,
                    filled: true,
                    loading: _isSubmitting,
                    onTap: _isSubmitting ? null : _submit,
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

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.enabled,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.inputBarBorder),
    );
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      autocorrect: false,
      style: AppTextStyles.body(fontSize: 14, color: colors.ink),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.body(fontSize: 13, color: colors.ink700),
        filled: true,
        fillColor: colors.inputBar,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.accent),
        ),
      ),
    );
  }
}

class _AdminDialogButton extends StatelessWidget {
  const _AdminDialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        // `ConfirmDialog`의 `_DialogButton`과 동일한 이유로 고정 높이
        // `SizedBox` 대신 최소 높이만 지정한다 — 접근성 글자 크기 설정이
        // 커져 라벨이 두 줄로 늘어나면 그만큼 버튼이 늘어나게 함(사용자
        // 요청으로 발견).
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: filled ? colors.accent : null,
        side: filled ? BorderSide.none : BorderSide(color: colors.accent),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        overlayColor: colors.accentTint08,
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: filled ? colors.paper : colors.accentBright,
              ),
            )
          : Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 13.5,
                color: filled ? colors.paper : colors.accentBright,
                letterSpacing: .3,
              ),
            ),
    );
  }
}
