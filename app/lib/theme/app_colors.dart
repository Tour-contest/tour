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
    required this.kakaoContainer,
    required this.kakaoSymbol,
    required this.naverContainer,
    required this.naverForeground,
  });

  /// 배경(종이) 색.
  final Color paper;

  /// 본문/아이콘 등 전경(잉크) 색.
  final Color ink;

  /// 단일 액센트. 항상 스트로크(테두리·밑줄·괘선)로만 사용.
  final Color gold;

  /// 텍스트로 쓰는 골드 — 배경 대비 확보용 변형.
  final Color gold700;

  /// 카카오 로그인 버튼 컨테이너 색(#FEE500). 카카오 브랜드 가이드 준수용 예외 — 다른 곳에서는 사용하지 않는다.
  final Color kakaoContainer;

  /// 카카오 로그인 버튼 심볼 색(#000000). 카카오 브랜드 가이드 준수용 예외.
  final Color kakaoSymbol;

  /// 네이버 로그인 버튼 컨테이너 색(#03A94D). 네이버 브랜드 가이드 준수용 예외 — 다른 곳에서는 사용하지 않는다.
  final Color naverContainer;

  /// 네이버 로그인 버튼 로고/레이블 색(#FFFFFF). 네이버 브랜드 가이드 준수용 예외.
  final Color naverForeground;

  Color get ink800 => ink.withAlpha(219);
  Color get ink700 => ink.withAlpha(179);
  Color get ink600 => ink.withAlpha(148);
  Color get divider => ink.withAlpha(36);

  Color get goldTint08 => gold.withAlpha(20);
  Color get goldTint14 => gold.withAlpha(36);

  /// 카카오 로그인 버튼 레이블 색(#000000 85%).
  Color get kakaoLabel => kakaoSymbol.withAlpha(217);

  static const light = AppColors(
    paper: Color(0xFFF3F2F2),
    ink: Color(0xFF201F1D),
    gold: Color(0xFFB68235),
    gold700: Color(0xFF7A5620),
    kakaoContainer: Color(0xFFFEE500),
    kakaoSymbol: Color(0xFF000000),
    naverContainer: Color(0xFF03A94D),
    naverForeground: Color(0xFFFFFFFF),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? light;
  }

  @override
  AppColors copyWith({
    Color? paper,
    Color? ink,
    Color? gold,
    Color? gold700,
    Color? kakaoContainer,
    Color? kakaoSymbol,
    Color? naverContainer,
    Color? naverForeground,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      ink: ink ?? this.ink,
      gold: gold ?? this.gold,
      gold700: gold700 ?? this.gold700,
      kakaoContainer: kakaoContainer ?? this.kakaoContainer,
      kakaoSymbol: kakaoSymbol ?? this.kakaoSymbol,
      naverContainer: naverContainer ?? this.naverContainer,
      naverForeground: naverForeground ?? this.naverForeground,
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
      kakaoContainer: Color.lerp(kakaoContainer, other.kakaoContainer, t)!,
      kakaoSymbol: Color.lerp(kakaoSymbol, other.kakaoSymbol, t)!,
      naverContainer: Color.lerp(naverContainer, other.naverContainer, t)!,
      naverForeground: Color.lerp(naverForeground, other.naverForeground, t)!,
    );
  }
}
