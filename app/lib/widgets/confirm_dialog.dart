import 'package:flutter/material.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 2버튼(취소 / 확인) 확인 팝업. "회원 탈퇴"·"로그아웃"처럼 제목·설명·확인
/// 버튼 문구만 다른 확인 다이얼로그에서 공용으로 사용한다(`SettingsScreen`,
/// 채팅 화면 헤더의 프로필 메뉴 "로그아웃").
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  /// 취소 버튼 문구. 기본값(`null`)이면 공용 `commonCancel`("취소")을 쓴다.
  /// 로그아웃 확인 팝업처럼 이 다이얼로그 하나만 다른 문구("취소하기")가
  /// 필요한 경우에만 넘긴다(사용자 요청).
  final String? cancelLabel;

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
                    label: cancelLabel ?? AppLocalizations.of(context)!.commonCancel,
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
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        // 접근성 글자 크기 설정이 커지면 라벨이 두 줄로 늘어날 수 있는데,
        // `SizedBox`로 높이를 44로 고정해두면 그 늘어난 텍스트가 잘리거나
        // 오버플로가 났다(사용자 요청으로 발견) — 최소 높이만 44로 두고
        // 필요하면 버튼이 그만큼 더 늘어나도록 바꿈.
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: filled ? colors.accent : null,
        side: filled ? BorderSide.none : BorderSide(color: colors.accent),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        overlayColor: colors.accentTint08,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(
          fontSize: 13.5,
          color: filled ? colors.paper : colors.accentBright,
          letterSpacing: .3,
        ),
      ),
    );
  }
}
