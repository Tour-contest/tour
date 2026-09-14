import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// 뒤로가기 버튼 + 가운데 정렬된 타이틀만 있는 단순 앱바. `app_header.dart`의
/// `AppHeader`(배경 슬롯 이미지(`assets/images/slot.png`) 장식 포함)가 필요
/// 없는 화면에서 쓴다. `settings_screen.dart`(옛 `_SettingsAppBar`)/
/// `history_screen.dart`/`attraction_detail_screen.dart`가 공유한다.
/// [title]이 길어질 수 있는 화면(관광지 이름 등)을 위해 최대 2줄까지 허용하고
/// 넘치면 말줄임표로 자른다 — 그만큼 헤더 높이도 최소 52에서 필요한 만큼
/// 늘어난다(기존 짧은 타이틀 화면은 한 줄에 다 들어가 높이가 그대로 52).
class PlainHeader extends StatelessWidget {
  const PlainHeader({super.key, required this.title});

  final String title;

  static const double _minHeight = 52;
  static const double _backButtonSize = 48;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
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
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading(color: colors.ink),
              ),
            ),
            const SizedBox(width: _backButtonSize),
          ],
        ),
      ),
    );
  }
}
