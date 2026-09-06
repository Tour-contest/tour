import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

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
        '$text $score',
        style: AppTextStyles.tabularNums(
          AppTextStyles.body(fontSize: 10.5, color: foreground),
        ),
      ),
    );
  }
}
