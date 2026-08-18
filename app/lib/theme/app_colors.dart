import 'package:flutter/material.dart';

/// Classical(에디토리얼/북 스타일) 팔레트. docs/DESIGN.md 참고. 라이트 테마만 지원한다.
///
/// [ThemeExtension]로 등록해둔다. 위젯에서는 `AppColors.of(context)`로 조회한다.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.ink,
    required this.gold,
    required this.gold700,
  });

  /// 배경(종이) 색.
  final Color paper;

  /// 본문/아이콘 등 전경(잉크) 색.
  final Color ink;

  /// 단일 액센트. 항상 스트로크(테두리·밑줄·괘선)로만 사용.
  final Color gold;

  /// 텍스트로 쓰는 골드 — 배경 대비 확보용 변형.
  final Color gold700;

  Color get ink800 => ink.withAlpha(219);
  Color get ink700 => ink.withAlpha(179);
  Color get ink600 => ink.withAlpha(148);
  Color get divider => ink.withAlpha(36);

  Color get goldTint08 => gold.withAlpha(20);
  Color get goldTint14 => gold.withAlpha(36);

  static const light = AppColors(
    paper: Color(0xFFF3F2F2),
    ink: Color(0xFF201F1D),
    gold: Color(0xFFB68235),
    gold700: Color(0xFF7A5620),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? light;
  }

  @override
  AppColors copyWith({Color? paper, Color? ink, Color? gold, Color? gold700}) {
    return AppColors(
      paper: paper ?? this.paper,
      ink: ink ?? this.ink,
      gold: gold ?? this.gold,
      gold700: gold700 ?? this.gold700,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      gold700: Color.lerp(gold700, other.gold700, t)!,
    );
  }
}
