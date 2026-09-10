import 'package:flutter/material.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/card_container.dart';

/// docs/NULNUL_MOBILE_SPEC.md S3: 채팅 빈 상태의 테마별 추천 2×2 그리드
/// (웰니스/의료관광/반려동반/캠핑). 카드를 탭하면 추천 칩과 동일하게 해당
/// 테마명을 그대로 새 사용자 메시지로 보낸다.
class ThemeGrid extends StatelessWidget {
  const ThemeGrid({super.key, required this.onThemeTap});

  final ValueChanged<String> onThemeTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (
        title: l10n.chatThemeWellnessTitle,
        subtitle: l10n.chatThemeWellnessSubtitle,
      ),
      (
        title: l10n.chatThemeMedicalTitle,
        subtitle: l10n.chatThemeMedicalSubtitle,
      ),
      (
        title: l10n.chatThemePetTitle,
        subtitle: l10n.chatThemePetSubtitle,
      ),
      (
        title: l10n.chatThemeCampingTitle,
        subtitle: l10n.chatThemeCampingSubtitle,
      ),
    ];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ThemeCard(option: options[0], onTap: onThemeTap),
            const SizedBox(width: 16),
            _ThemeCard(option: options[1], onTap: onThemeTap),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ThemeCard(option: options[2], onTap: onThemeTap),
            const SizedBox(width: 16),
            _ThemeCard(option: options[3], onTap: onThemeTap),
          ],
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.option, required this.onTap});

  final ({String title, String subtitle}) option;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
        onTap: () => onTap(option.title),
        child: SizedBox(
          width: 116,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 116),
            child: CardContainer(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading(
                        fontSize: 16,
                        color: colors.ink,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    option.subtitle,
                    textAlign: TextAlign.center,
                    style:
                        AppTextStyles.body(fontSize: 13, color: colors.ink600),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
