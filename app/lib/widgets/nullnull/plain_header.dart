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
/// [trailing]을 주면 우측 대칭용 빈 공간(`_backButtonSize` 너비) 대신 그
/// 위젯을 보여준다(사용자 요청 — `history_screen.dart`의 날짜 필터 토글
/// 버튼). 기본값(`null`)이면 기존처럼 뒤로가기 버튼과 시각적으로 균형을
/// 맞추는 빈 `SizedBox`를 쓴다.
class PlainHeader extends StatelessWidget {
  const PlainHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  static const double _minHeight = 52;
  static const double _backButtonSize = 48;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Padding(
        // 사용자 요청 — 시스템 상태 바(위 `SafeArea`가 만드는 상단 인셋)와
        // 이 헤더 내용이 너무 붙어 보여, 위쪽에만 8px 여백을 줌
        // (`ConstrainedBox`는 최솟값만 강제하므로, 뒤로가기 버튼(기본 탭
        // 영역 48)+이 8px이 52를 넘으면 헤더가 자연히 그만큼 더 커진다 —
        // 긴 제목이 2줄로 늘어날 때와 같은 방식).
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Row(
          children: [
            IconButton(
              icon: AppIcon(AppIconShape.chevronLeft,
                  size: 22, color: colors.ink),
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
            trailing ?? const SizedBox(width: _backButtonSize),
          ],
        ),
      ),
    );
  }
}
