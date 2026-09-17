import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 등급 + 집중률 점수 배지(예: "한적 23점"). 점수 뒤 단위(`congestionScoreSuffix`,
/// 한국어만 "점")는 언어별로 다를 수 있어 l10n으로 분리했다(영어는 빈 문자열이라
/// "Quiet 23"처럼 단위 없이 나온다). `attraction_detail_screen.dart`/`chat_card_view.dart`/
/// `alternatives_section.dart`가 공유한다.
class CongestionBadge extends StatelessWidget {
  const CongestionBadge({super.key, required this.level, required this.score});

  final Level level;
  final int score;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final (text, foreground) = switch (level) {
      Level.quiet => (l10n.congestionLevelQuiet, colors.quietText),
      Level.normal => (l10n.congestionLevelNormal, colors.normalText),
      Level.busy => (
          score >= 75 ? l10n.congestionLevelVeryBusy : l10n.congestionLevelBusy,
          colors.busyText,
        ),
    };
    final border = switch (level) {
      Level.quiet => colors.quietBorder,
      Level.normal => colors.normalBorder,
      Level.busy => colors.busyBorder,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$text $score${l10n.congestionScoreSuffix}',
        style: AppTextStyles.tabularNums(
          AppTextStyles.body(fontSize: 10.5, color: foreground),
        ),
      ),
    );
  }
}
