import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// docs/DESIGN.md: "추천 프롬프트: 헤어라인 리스트 행, 우측 ↗ 골드 화살표".
class SuggestedPromptRow extends StatelessWidget {
  const SuggestedPromptRow(
      {super.key,
      required this.text,
      required this.onTap,
      this.isLast = false});

  final String text;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.divider),
            bottom:
                isLast ? BorderSide(color: colors.divider) : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: AppTextStyles.body(fontSize: 13.5, color: colors.ink)),
            ),
            const SizedBox(width: 10),
            AppIcon(AppIconShape.arrowUpRight, size: 13, color: colors.gold),
          ],
        ),
      ),
    );
  }
}
