import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';

class NoDataCard extends StatelessWidget {
  const NoDataCard({
    super.key,
    required this.actions,
    required this.onActionTap,
  });

  final List<String> actions;
  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 순수 장식이라 VoiceOver 시맨틱 트리에서 제외한다(사용자 요청 —
          // VoiceOver 지원, 채팅 화면. `chat_fallback_prompt.dart`와 동일한
          // 처리).
          const ExcludeSemantics(child: Mascot(size: 48)),
          const SizedBox(height: 12),
          for (var i = 0; i < actions.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == actions.length - 1 ? 0 : 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => onActionTap(actions[i]),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.surfaceMutedBorder),
                    backgroundColor: colors.surfaceMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    overlayColor: colors.accentTint08,
                  ),
                  child: Text(
                    actions[i],
                    style:
                        AppTextStyles.body(fontSize: 13.5, color: colors.ink),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
