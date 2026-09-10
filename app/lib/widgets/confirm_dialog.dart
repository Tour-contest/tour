import 'package:flutter/material.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 2버튼(취소 / 확인) 확인 팝업. "연결 끊기"·"로그아웃"처럼 제목·설명·확인
/// 버튼 문구만 다른 확인 다이얼로그에서 공용으로 사용한다(`SettingsScreen`,
/// 채팅 화면 헤더의 프로필 메뉴 "로그아웃").
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.graphite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.inputBarBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading(fontSize: 17, color: colors.ink),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                  fontSize: 12.5, color: colors.ink700, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: AppLocalizations.of(context)!.commonCancel,
                    filled: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: confirmLabel,
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? colors.accent : null,
          side: filled ? BorderSide.none : BorderSide(color: colors.accent),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          overlayColor: colors.accentTint08,
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 13.5,
            color: filled ? colors.paper : colors.accentBright,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}
