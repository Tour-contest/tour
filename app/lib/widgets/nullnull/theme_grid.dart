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
        // `IntrinsicHeight` + `CrossAxisAlignment.stretch`로 같은 행의 두
        // 카드가 서로의 콘텐츠 높이(글자 크기 설정에 따라 달라짐)에 맞춰
        // 항상 같은 높이가 되도록 한다 — 이게 없으면 각 카드가 `minHeight`
        // 아래로는 자기 콘텐츠 길이만큼만 커져서, 부제 길이가 서로 다른
        // 카드끼리 높이가 들쭉날쭉해진다.
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ThemeCard(option: options[0], onTap: onThemeTap),
              const SizedBox(width: 16),
              _ThemeCard(option: options[1], onTap: onThemeTap),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ThemeCard(option: options[2], onTap: onThemeTap),
              const SizedBox(width: 16),
              _ThemeCard(option: options[3], onTap: onThemeTap),
            ],
          ),
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
                // 같은 행의 카드끼리 높이를 맞춘 뒤(`IntrinsicHeight`) 이
                // 카드가 더 짧은 콘텐츠를 가진 쪽이면 남는 공간이 생기는데,
                // 위쪽에 쏠리지 않고 세로로 가운데 놓이도록 한다.
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    option.title,
                    textAlign: TextAlign.center,
                    // 이 4개 테마 카드는 접근성 글자 크기 설정과 무관하게
                    // 항상 기본 크기로 고정한다(사용자 요청).
                    textScaler: TextScaler.noScaling,
                    style: AppTextStyles.heading(
                        fontSize: 16,
                        color: colors.ink,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    option.subtitle,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
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
