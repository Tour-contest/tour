import 'package:flutter/material.dart';

/// 제목·본문 모두 WantedSans(로컬 번들 폰트, `assets/fonts/`). docs/DESIGN.md 참고.
///
/// 색은 라이트/다크 테마에 따라 달라지므로 항상 [AppColors]에서 명시적으로
/// 받아서 넘긴다 (`AppTextStyles.body(color: AppColors.of(context).ink)`).
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'WantedSans';

  /// 브랜드/큰 디스플레이용 — normal(400) 고정.
  static TextStyle display({double fontSize = 56, required Color color}) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: 1.0,
      color: color,
    );
  }

  /// 화면/섹션 제목, 장소명 등 — 세미볼드 이하.
  static TextStyle heading({
    double fontSize = 19,
    FontWeight weight = FontWeight.w500,
    required Color color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  /// 본문.
  static TextStyle body({
    double fontSize = 14.5,
    required Color color,
    double? height,
    FontStyle fontStyle = FontStyle.normal,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }

  /// 숫자·날짜 등 tabular 정렬이 필요한 텍스트.
  static TextStyle tabularNums(TextStyle base) {
    return base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }
}
