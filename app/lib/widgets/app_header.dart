import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// docs/DESIGN.md: "헤더(모든 채팅/히스토리 화면 공통)".
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onLeadingTap,
    this.onTrailingTap,
    this.leadingTooltip,
    this.trailingTooltip,
    this.backgroundColor,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  final VoidCallback? onLeadingTap;
  final VoidCallback? onTrailingTap;

  final String? leadingTooltip;
  final String? trailingTooltip;

  /// 화면별로 배경색을 달리해야 할 때만 지정한다(예: 채팅 화면). 지정하지
  /// 않으면 `colors.paper`를 쓴다.
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: preferredSize.height,
      // 사용자 요청 — 시스템 상태 바(위 `SafeArea`가 만드는 상단 인셋)와 이
      // 헤더 내용이 너무 붙어 보여, 위쪽에만 8px 여백을 줘서 `_HeaderSlot`의
      // 탭 영역(44)과 정확히 맞아떨어지게 함(52 - 8 = 44, 기존엔 Row의
      // 기본 세로 중앙 정렬로 위/아래 각각 ~4px씩만 생겼었음).
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.paper,
      ),
      child: Row(
        children: [
          _HeaderSlot(
              onTap: onLeadingTap, tooltip: leadingTooltip, child: leading),
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title!,
                          style: AppTextStyles.heading(color: colors.ink)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.body(
                            fontSize: 10,
                            color: colors.accentBright,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          _HeaderSlot(
              onTap: onTrailingTap, tooltip: trailingTooltip, child: trailing),
        ],
      ),
    );
  }
}

class _HeaderSlot extends StatelessWidget {
  const _HeaderSlot({this.child, this.onTap, this.tooltip});

  final Widget? child;
  final VoidCallback? onTap;
  final String? tooltip;

  static const double _tapSize = 44;

  @override
  Widget build(BuildContext context) {
    final slot = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _tapSize,
        height: _tapSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset('assets/images/slot.png', width: 40, height: 40),
            if (child != null) child!,
          ],
        ),
      ),
    );
    final decorated =
        tooltip == null ? slot : Tooltip(message: tooltip, child: slot);
    // `GestureDetector`는 탭 액션은 자동으로 시맨틱 트리에 연결하지만(Flutter
    // 기본 동작) `button` role은 안 붙고, `Tooltip`이 주는 시맨틱스도 `label`이
    // 아니라 `tooltip` 속성이라 VoiceOver가 안내 문구를 그대로 안 읽어줄 수
    // 있다 — `onTap`/`tooltip`이 둘 다 있을 때만(=실제 아이콘 버튼일 때만)
    // 명시적으로 버튼 role과 라벨을 준다(사용자 요청 — VoiceOver 지원, 채팅
    // 화면. `_ProfileAvatarButton`처럼 자체 제스처를 갖고 이 슬롯의 `onTap`을
    // 안 쓰는 경우엔 영향 없음).
    if (onTap == null || tooltip == null) return decorated;
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onTap,
      child: ExcludeSemantics(child: decorated),
    );
  }
}
