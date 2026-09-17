import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: colors.graphite,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(21),
              topRight: Radius.circular(21),
              bottomRight: Radius.circular(8),
              bottomLeft: Radius.circular(21),
            ),
          ),
          child: Text(
            text,
            style:
                AppTextStyles.body(color: colors.ink, height: 1.5, fontSize: 14)
                    .copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
