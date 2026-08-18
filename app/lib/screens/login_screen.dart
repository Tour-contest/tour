import 'package:flutter/material.dart';

import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/screens/chat_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// 온보딩 다음에 노출되는 로그인 화면. SNS 로그인만으로 로그인/회원가입을
/// 함께 처리하며, 실제 SNS 인증 연동 전 단계라 탭 시 채팅 화면으로 바로
/// 이동한다(canned 프로토타입).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  SnsProvider? _lastProvider;

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

  Future<void> _loginWith(SnsProvider provider) async {
    await LoginPreference.saveLastProvider(provider);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Column(
          children: [
            AppHeader(
              title: '로그인',
              leading: IconButton(
                icon: AppIcon(AppIconShape.chevronLeft,
                    size: 18, color: colors.ink),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '뒤로',
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 32, 26, 34),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '로그인 · 회원가입',
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: colors.gold700,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'SNS 계정으로\n간편하게 시작하세요',
                          style: AppTextStyles.heading(
                              fontSize: 28, color: colors.ink, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '별도 회원가입 절차 없이 아래 계정으로 바로 이용할 수 있어요.',
                          style: AppTextStyles.body(
                              fontSize: 13.5, color: colors.ink700, height: 1.6),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        _SnsLoginButton(
                          icon: AppIconShape.kakao,
                          label: '${SnsProvider.kakao.label}로 시작하기',
                          showRecentBadge: _lastProvider == SnsProvider.kakao,
                          onTap: () => _loginWith(SnsProvider.kakao),
                        ),
                        const SizedBox(height: 12),
                        _SnsLoginButton(
                          icon: AppIconShape.naver,
                          label: '${SnsProvider.naver.label}로 시작하기',
                          showRecentBadge: _lastProvider == SnsProvider.naver,
                          onTap: () => _loginWith(SnsProvider.naver),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '로그인 시 서비스 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body(
                              fontSize: 11, color: colors.ink600, height: 1.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  });

  final AppIconShape icon;
  final String label;
  final bool showRecentBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.gold),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              overlayColor: colors.goldTint08,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: 18, color: colors.gold),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AppTextStyles.body(
                      fontSize: 15, color: colors.ink, letterSpacing: .6),
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
                border: Border.all(color: colors.gold),
              ),
              child: Text(
                '최근 로그인',
                style: AppTextStyles.body(
                  fontSize: 9.5,
                  color: colors.gold700,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
