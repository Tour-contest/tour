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
    this.backgroundColor,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.paper,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 44, height: 44, child: leading ?? const SizedBox.shrink()),
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
          SizedBox(
              width: 44,
              height: 44,
              child: trailing ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
