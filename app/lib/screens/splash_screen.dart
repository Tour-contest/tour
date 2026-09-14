import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/auth_service.dart';
import 'package:nullnull/data/auth_token_storage.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';

/// 앱 최초 진입 시 잠깐 노출되는 브랜드 스플래시 화면. 로고 등장 애니메이션을
/// 보여주는 동안 저장된 토큰으로 자동 로그인을 시도해, 끝나면 `/chat`(자동
/// 로그인 성공)/`/login`(토큰 없음 또는 갱신 실패) 중 하나로 넘어간다. 갱신
/// 실패는 원인(네트워크 오류/세션 만료 등)과 무관하게 알림 없이 조용히
/// 로그인 화면으로 보낸다(사용자 요청 — 로그인 화면 자체가 이미 자연스러운
/// 다음 단계라 별도 안내가 필요 없다고 판단). 온보딩 화면은 현재 화면
/// 흐름에서 제외되어 있으며(코드/라우트는 유지), 재도입 시 이 화면의
/// 목적지만 다시 바꾸면 된다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _navigateAfter = Duration(milliseconds: 2400);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Future<String> _destinationFuture;
  Timer? _navigateTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    // 애니메이션이 도는 동안 백그라운드에서 미리 시도해둬서, 타이머가
    // 끝나는 시점엔 대부분 이미 결과가 나와 있어 체감 지연이 없다.
    _destinationFuture = _resolveDestination();
    _navigateTimer = Timer(_navigateAfter, _navigate);
  }

  /// 저장된 토큰이 없으면 로그인 화면으로, 있으면 [AuthService.refresh]로
  /// 갱신을 시도해 성공하면 채팅 화면으로 자동 로그인한다. 갱신 실패는
  /// 원인과 무관하게(네트워크 오류든 세션 만료든) 조용히 로그인 화면으로
  /// 보낸다 — 어차피 로그인 화면이 다음 단계라 별도 안내가 필요 없다.
  Future<String> _resolveDestination() async {
    try {
      final tokens = await AuthTokenStorage.read();
      if (tokens == null) return RouteNames.login;
      await AuthService.refresh();
      AppLog.logger.i('[Splash] 자동 로그인 성공');
      return RouteNames.chat;
    } catch (e, stackTrace) {
      AppLog.logger
          .w('[Splash] 자동 로그인 실패 → 로그인 화면으로 이동', error: e, stackTrace: stackTrace);
      return RouteNames.login;
    }
  }

  Future<void> _navigate() async {
    final destination = await _destinationFuture;
    if (!mounted) return;
    context.goNamed(destination);
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(size: 130),
                const SizedBox(height: 36),
                SvgPicture.asset('assets/images/typography.svg'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
