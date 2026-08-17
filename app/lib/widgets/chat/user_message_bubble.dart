import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// docs/DESIGN.md: "사용자 메시지: 우측 정렬, 이탤릭, 오른쪽 2px 골드 세로 괘선".
class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          padding: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: colors.gold, width: 2)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: AppTextStyles.body(
              color: colors.ink800,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
