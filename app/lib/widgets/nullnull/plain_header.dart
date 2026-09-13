import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// 뒤로가기 버튼 + 가운데 정렬된 타이틀만 있는 단순 앱바. `app_header.dart`의
/// `AppHeader`(배경 슬롯 이미지(`assets/images/slot.png`) 장식 포함)가 필요
/// 없는 화면에서 쓴다. `settings_screen.dart`(옛 `_SettingsAppBar`)와
/// `history_screen.dart`가 공유한다.
class PlainHeader extends StatelessWidget {
  const PlainHeader({super.key, required this.title});

  final String title;

  static const double _backButtonSize = 48;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: AppIcon(AppIconShape.chevronLeft,
                  size: 18, color: colors.ink),
              onPressed: () => context.pop(),
              tooltip: l10n.commonBack,
            ),
            Expanded(
              child: Center(
                child: Text(title,
                    style: AppTextStyles.heading(color: colors.ink)),
              ),
            ),
            const SizedBox(width: _backButtonSize),
          ],
        ),
      ),
    );
  }
}
