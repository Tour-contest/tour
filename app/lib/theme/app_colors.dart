import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.loginBackground,
    required this.drawerBackground,
    required this.ink,
    required this.accent,
    required this.accentBright,
    required this.card,
    required this.cardBorder,
    required this.surfaceMuted,
    required this.surfaceMutedBorder,
    required this.inputBar,
    required this.inputBarBorder,
    required this.userBubble,
    required this.quietText,
    required this.quietBorder,
    required this.quietChart,
    required this.normalText,
    required this.normalBorder,
    required this.normalChart,
    required this.busyText,
    required this.busyBorder,
    required this.busyChart,
    required this.kakaoContainer,
    required this.kakaoSymbol,
    required this.naverContainer,
    required this.naverForeground,
    required this.loginHeadlineGradientStart,
    required this.loginHeadlineGradientMid,
    required this.loginHeadlineGradientEnd,
    required this.loginSubheadline,
  });

  final Color paper;

  /// 로그인 화면 전용 배경색. 앱 전역 배경(`paper`)과 별도로 지정한다.
  final Color loginBackground;

  final Color drawerBackground;

  final Color ink;

  final Color accent;

  final Color accentBright;

  final Color card;

  final Color cardBorder;

  final Color surfaceMuted;

  final Color surfaceMutedBorder;

  final Color inputBar;

  final Color inputBarBorder;

  final Color userBubble;

  final Color quietText;
  final Color quietBorder;
  final Color quietChart;

  final Color normalText;
  final Color normalBorder;
  final Color normalChart;

  final Color busyText;
  final Color busyBorder;
  final Color busyChart;

  /// 카카오 로그인 버튼 컨테이너 색(#FEE500). 카카오 브랜드 가이드 준수용 예외 — 다른 곳에서는 사용하지 않는다.
  final Color kakaoContainer;

  /// 카카오 로그인 버튼 심볼 색(#000000). 카카오 브랜드 가이드 준수용 예외.
  final Color kakaoSymbol;

  /// 네이버 로그인 버튼 컨테이너 색(#03A94D). 네이버 브랜드 가이드 준수용 예외 — 다른 곳에서는 사용하지 않는다.
  final Color naverContainer;

  /// 네이버 로그인 버튼 로고/레이블 색(#FFFFFF). 네이버 브랜드 가이드 준수용 예외.
  final Color naverForeground;

  /// 로그인 화면 그라디언트 헤드라인 상단 색(#A3F1F9, 0%).
  final Color loginHeadlineGradientStart;

  /// 로그인 화면 그라디언트 헤드라인 중간 색(#6FC1FC, 39.9%).
  final Color loginHeadlineGradientMid;

  /// 로그인 화면 그라디언트 헤드라인 하단 색(#309AE6, 100%).
  final Color loginHeadlineGradientEnd;

  /// 로그인 화면 그라디언트 헤드라인 아래 보조 설명 색(#7D8899).
  final Color loginSubheadline;

  Color get ink800 => ink.withAlpha(230);

  Color get ink700 => const Color(0xFFA9B6BF);

  Color get ink600 => const Color(0xFF77848D);

  Color get divider => cardBorder;

  Color get accentTint08 => accent.withAlpha(20);
  Color get accentTint14 => accent.withAlpha(36);

  Color get scrim => const Color(0xFF0A0D0F).withAlpha(153);

  /// 로그인 화면 최하단 장식 바 그라디언트 배경(헤드라인과 같은 3색, 13% 알파).
  Color get loginBottomBarGradientStart =>
      loginHeadlineGradientStart.withAlpha(33);
  Color get loginBottomBarGradientMid => loginHeadlineGradientMid.withAlpha(33);
  Color get loginBottomBarGradientEnd => loginHeadlineGradientEnd.withAlpha(33);

  /// 로그인 화면 최하단 장식 바의 inset 하이라이트 색(#FFFFFF, 12% 알파).
  Color get loginBottomBarGlow => const Color(0xFFFFFFFF).withAlpha(31);

  /// 카카오 로그인 버튼 레이블 색(#000000 85%).
  Color get kakaoLabel => kakaoSymbol.withAlpha(217);

  static const dark = AppColors(
    paper: Color(0xFF1C2023),
    loginBackground: Color(0xFF20232C),
    drawerBackground: Color(0xFF191C1F),
    ink: Color(0xFFF2F6F9),
    accent: Color(0xFF68BDF9),
    accentBright: Color(0xFFA9EDFD),
    card: Color(0xFF272D32),
    cardBorder: Color(0xFF343D44),
    surfaceMuted: Color(0xFF2F373D),
    surfaceMutedBorder: Color(0xFF3D474E),
    inputBar: Color(0xFF3B4247),
    inputBarBorder: Color(0xFF4A5258),
    userBubble: Color(0xFF2E363C),
    quietText: Color(0xFF4CD980),
    quietBorder: Color(0xFF2F9E5B),
    quietChart: Color(0xFF25B34B),
    normalText: Color(0xFFF2C94C),
    normalBorder: Color(0xFFB08417),
    normalChart: Color(0xFFD9A318),
    busyText: Color(0xFFEF8D5A),
    busyBorder: Color(0xFFB0562A),
    busyChart: Color(0xFFC8561D),
    kakaoContainer: Color(0xFFFEE500),
    kakaoSymbol: Color(0xFF000000),
    naverContainer: Color(0xFF03A94D),
    naverForeground: Color(0xFFFFFFFF),
    loginHeadlineGradientStart: Color(0xFFA3F1F9),
    loginHeadlineGradientMid: Color(0xFF6FC1FC),
    loginHeadlineGradientEnd: Color(0xFF309AE6),
    loginSubheadline: Color(0xFF7D8899),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? dark;
  }

  @override
  AppColors copyWith({
    Color? paper,
    Color? loginBackground,
    Color? drawerBackground,
    Color? ink,
    Color? accent,
    Color? accentBright,
    Color? card,
    Color? cardBorder,
    Color? surfaceMuted,
    Color? surfaceMutedBorder,
    Color? inputBar,
    Color? inputBarBorder,
    Color? userBubble,
    Color? quietText,
    Color? quietBorder,
    Color? quietChart,
    Color? normalText,
    Color? normalBorder,
    Color? normalChart,
    Color? busyText,
    Color? busyBorder,
    Color? busyChart,
    Color? kakaoContainer,
    Color? kakaoSymbol,
    Color? naverContainer,
    Color? naverForeground,
    Color? loginHeadlineGradientStart,
    Color? loginHeadlineGradientMid,
    Color? loginHeadlineGradientEnd,
    Color? loginSubheadline,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      loginBackground: loginBackground ?? this.loginBackground,
      drawerBackground: drawerBackground ?? this.drawerBackground,
      ink: ink ?? this.ink,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceMutedBorder: surfaceMutedBorder ?? this.surfaceMutedBorder,
      inputBar: inputBar ?? this.inputBar,
      inputBarBorder: inputBarBorder ?? this.inputBarBorder,
      userBubble: userBubble ?? this.userBubble,
      quietText: quietText ?? this.quietText,
      quietBorder: quietBorder ?? this.quietBorder,
      quietChart: quietChart ?? this.quietChart,
      normalText: normalText ?? this.normalText,
      normalBorder: normalBorder ?? this.normalBorder,
      normalChart: normalChart ?? this.normalChart,
      busyText: busyText ?? this.busyText,
      busyBorder: busyBorder ?? this.busyBorder,
      busyChart: busyChart ?? this.busyChart,
      kakaoContainer: kakaoContainer ?? this.kakaoContainer,
      kakaoSymbol: kakaoSymbol ?? this.kakaoSymbol,
      naverContainer: naverContainer ?? this.naverContainer,
      naverForeground: naverForeground ?? this.naverForeground,
      loginHeadlineGradientStart:
          loginHeadlineGradientStart ?? this.loginHeadlineGradientStart,
      loginHeadlineGradientMid:
          loginHeadlineGradientMid ?? this.loginHeadlineGradientMid,
      loginHeadlineGradientEnd:
          loginHeadlineGradientEnd ?? this.loginHeadlineGradientEnd,
      loginSubheadline: loginSubheadline ?? this.loginSubheadline,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      loginBackground: Color.lerp(loginBackground, other.loginBackground, t)!,
      drawerBackground:
          Color.lerp(drawerBackground, other.drawerBackground, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBright: Color.lerp(accentBright, other.accentBright, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceMutedBorder:
          Color.lerp(surfaceMutedBorder, other.surfaceMutedBorder, t)!,
      inputBar: Color.lerp(inputBar, other.inputBar, t)!,
      inputBarBorder: Color.lerp(inputBarBorder, other.inputBarBorder, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      quietText: Color.lerp(quietText, other.quietText, t)!,
      quietBorder: Color.lerp(quietBorder, other.quietBorder, t)!,
      quietChart: Color.lerp(quietChart, other.quietChart, t)!,
      normalText: Color.lerp(normalText, other.normalText, t)!,
      normalBorder: Color.lerp(normalBorder, other.normalBorder, t)!,
      normalChart: Color.lerp(normalChart, other.normalChart, t)!,
      busyText: Color.lerp(busyText, other.busyText, t)!,
      busyBorder: Color.lerp(busyBorder, other.busyBorder, t)!,
      busyChart: Color.lerp(busyChart, other.busyChart, t)!,
      kakaoContainer: Color.lerp(kakaoContainer, other.kakaoContainer, t)!,
      kakaoSymbol: Color.lerp(kakaoSymbol, other.kakaoSymbol, t)!,
      naverContainer: Color.lerp(naverContainer, other.naverContainer, t)!,
      naverForeground: Color.lerp(naverForeground, other.naverForeground, t)!,
      loginHeadlineGradientStart: Color.lerp(
          loginHeadlineGradientStart, other.loginHeadlineGradientStart, t)!,
      loginHeadlineGradientMid: Color.lerp(
          loginHeadlineGradientMid, other.loginHeadlineGradientMid, t)!,
      loginHeadlineGradientEnd: Color.lerp(
          loginHeadlineGradientEnd, other.loginHeadlineGradientEnd, t)!,
      loginSubheadline:
          Color.lerp(loginSubheadline, other.loginSubheadline, t)!,
    );
  }
}
