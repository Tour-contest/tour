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
import 'package:nullnull/widgets/nullnull/mascot.dart';

/// 온보딩 다음에 노출되는 로그인 화면. SNS 로그인만으로 로그인/회원가입을 함께
/// 처리한다. 카카오는 `kakao_flutter_sdk_user`로 실제 로그인을 수행한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  SnsProvider? _lastProvider;

  ///  진행 중에는 화면 터치·뒤로가기를 막는다.
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _loadLastProvider();
  }

  Future<void> _loadLastProvider() async {
    final provider = await LoginPreference.readLastProvider();
    if (!mounted) return;
    setState(() => _lastProvider = provider);
  }

  Future<void> _completeLogin(SnsProvider provider) async {
    await LoginPreference.saveLastProvider(provider);
    unawaited(AnalyticsService.logLogin(provider));
    if (!mounted) return;
    context.goNamed(RouteNames.chat);
  }

  Future<void> _loginWithKakao() async {
    setState(() => _isLoggingIn = true);
    try {
      final installed = await isKakaoTalkInstalled();
      final OAuthToken token = installed
          ? await UserApi.instance.loginWithKakaoTalk()
          : await UserApi.instance.loginWithKakaoAccount();
      AppLog.logger.i('카카오 로그인 성공, 백엔드 토큰 교환 시작');
      await AuthService.loginWithKakao(token.accessToken);
      await _saveKakaoProfile();
      await _completeLogin(SnsProvider.kakao);
    } catch (error) {
      if (error is PlatformException && error.code == 'CANCELED') return;
      AppLog.logger.e('카카오 로그인 실패', error: error);
      if (!mounted) return;
      // 오프라인 상태면 전역 오프라인 다이얼로그(NetworkStatusListener)가 이미 화면
      // 전체를 덮고 안내 중이라, 이 화면의 스낵바는 다이얼로그 뒤에 가려 안 보인 채로
      // 사라진다. 그런 경우는 중복 안내를 띄우지 않는다.
      if (!await ConnectivityService().isOnline()) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loginKakaoError)),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
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
    return PopScope(
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
                          showRecentBadge: _lastProvider == SnsProvider.kakao,
                          onTap: _isLoggingIn ? null : _loginWithKakao,
                          backgroundColor: colors.kakaoContainer,
                          labelColor: colors.kakaoLabel,
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
  }
}

class _SnsLoginButton extends StatelessWidget {
  const _SnsLoginButton({
    required this.icon,
    required this.label,
    required this.showRecentBadge,
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
  final bool showRecentBadge;
  final VoidCallback? onTap;

  /// 각 SNS 브랜드 가이드에 따른 버튼 채움 색.
  final Color backgroundColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
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
        ),
        if (showRecentBadge)
          Positioned(
            top: -9,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.paper,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: colors.accent),
              ),
              child: Text(
                AppLocalizations.of(context)!.loginRecentBadge,
                style: AppTextStyles.body(
                  fontSize: 9.5,
                  color: colors.accentBright,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
