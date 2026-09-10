import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';

/// 앱 최초 진입 시 잠깐 노출되는 브랜드 스플래시 화면. 로고 등장 애니메이션을
/// 보여준 뒤 자동으로 로그인 화면으로 넘어간다. 온보딩 화면은 현재 화면
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
    _navigateTimer = Timer(_navigateAfter, _goToLogin);
  }

  void _goToLogin() {
    if (!mounted) return;
    context.goNamed(RouteNames.login);
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
