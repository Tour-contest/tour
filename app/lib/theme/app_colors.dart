import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.loginBackground,
    required this.loginBackgroundGlow,
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
    required this.userBubbleBorder,
    required this.chatSendButton,
    required this.quietText,
    required this.quietChart,
    required this.normalText,
    required this.normalChart,
    required this.busyText,
    required this.busyChart,
    required this.kakaoContainer,
    required this.kakaoSymbol,
    required this.loginHeadlineGradientStart,
    required this.loginHeadlineGradientMid,
    required this.loginHeadlineGradientEnd,
    required this.loginSubheadline,
    required this.voiceListeningHint,
    required this.graphite,
    required this.crowdChartBackground,
    required this.mapSheetGradientEnd,
    required this.dateFilterActiveBackground,
    required this.toastBorder,
    required this.alternativeReasonText,
    required this.congestionQuiet,
    required this.congestionNormal,
    required this.congestionBusy,
    required this.chatCardAccent,
  });

  final Color paper;

  /// 로그인 화면 전용 배경색. 앱 전역 배경(`paper`)과 별도로 지정한다.
  final Color loginBackground;

  /// 로그인 화면 상단(헤드라인·마스코트 영역) 배경 그라디언트 시작색. 화면
  /// 55% 지점에서 `loginBackground`로 이어진다.
  final Color loginBackgroundGlow;

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

  /// 사용자 채팅 말풍선 테두리색(#D8D8D8).
  final Color userBubbleBorder;

  /// 채팅 입력바 전송 버튼 배경색(#309AE6).
  final Color chatSendButton;

  final Color quietText;
  final Color quietChart;

  final Color normalText;
  final Color normalChart;

  final Color busyText;
  final Color busyChart;

  /// 카카오 로그인 버튼 컨테이너 색(#FEE500). 카카오 브랜드 가이드 준수용 예외 — 다른 곳에서는 사용하지 않는다.
  final Color kakaoContainer;

  /// 카카오 로그인 버튼 심볼 색(#000000). 카카오 브랜드 가이드 준수용 예외.
  final Color kakaoSymbol;

  /// 로그인 화면 그라디언트 헤드라인 상단 색(#A3F1F9, 0%).
  final Color loginHeadlineGradientStart;

  /// 로그인 화면 그라디언트 헤드라인 중간 색(#6FC1FC, 39.9%).
  final Color loginHeadlineGradientMid;

  /// 로그인 화면 그라디언트 헤드라인 하단 색(#309AE6, 100%).
  final Color loginHeadlineGradientEnd;

  /// 로그인 화면 그라디언트 헤드라인 아래 보조 설명 색(#7D8899).
  final Color loginSubheadline;

  /// 음성 입력 배지(`VoiceListeningToast`) 둘째 줄("탭해서 종료") 보조 텍스트 색(#737B87).
  final Color voiceListeningHint;

  /// 어두운 카드/시트 배경색(#292C36). `MapAppSheet`, `history_screen.dart`의
  /// `_HistoryTile`, `AppToast` 등이 공유한다.
  final Color graphite;

  /// `CrowdBarChart`(혼잡도 막대 그래프) 배경색(#333743).
  final Color crowdChartBackground;

  /// `MapAppSheet` 배경 그라디언트 하단 색(#17191F, 100% — 상단은 `graphite`).
  final Color mapSheetGradientEnd;

  /// `history_screen.dart`의 `_DateFilterMenuItem`에서 현재 선택된(active)
  /// 필터 항목 배경색(#343843).
  final Color dateFilterActiveBackground;

  /// `AppToast` 배경 테두리색(#E4E4E4).
  final Color toastBorder;

  /// `AlternativeCard`의 점수 차이·거리 텍스트 색(#698EA8).
  final Color alternativeReasonText;

  /// `CongestionBadge`의 "한적" 텍스트·테두리 색(#15B836). 앱 전역에서 재사용하는
  /// `quietText`(로그인 화면·`attraction_detail_screen.dart`의 검색 관심도
  /// 등에서도 쓰임)와 별개로, 이 배지 전용으로 뺐다.
  final Color congestionQuiet;

  /// `CongestionBadge`의 "보통" 텍스트·테두리 색(#D3A418).
  final Color congestionNormal;

  /// `CongestionBadge`의 "혼잡"/"매우 혼잡" 텍스트·테두리 색(#B84B15).
  final Color congestionBusy;

  /// 채팅 카드(`chat_card_view.dart`), 관광지 상세 화면(`attraction_detail_screen.dart`),
  /// 설정 화면(`settings_screen.dart`) 강조 텍스트/막대 그래프에 쓰는 색
  /// (#46A8EE, 사용자 요청으로 화면들에 차례로 반영). 앱 전역 `accentBright`
  /// (로그인·앱바 등에서는 여전히 옛 색 그대로 쓰임)와는 별개 토큰이다 —
  /// `CrowdBarChart`처럼 여러 화면이 공유하는 위젯은 `barColor` 파라미터로
  /// 이 색을 명시적으로 받을 때만 적용되고, 파라미터를 안 주면 기본값은
  /// 여전히 `accentBright`다(이름과 달리 이제 채팅 카드 전용은 아니지만,
  /// 처음 이 색을 도입한 위치를 그대로 이름에 남겨둠).
  final Color chatCardAccent;

  Color get ink800 => ink.withAlpha(230);

  Color get ink700 => const Color(0xFFA9B6BF);

  Color get ink600 => const Color(0xFF77848D);

  Color get divider => cardBorder;

  Color get accentTint08 => accent.withAlpha(20);
  Color get accentTint14 => accent.withAlpha(36);

  Color get scrim => const Color(0xFF0A0D0F).withAlpha(153);

  /// `AppToast`의 box-shadow 색(#000000, 18% 알파).
  Color get toastShadow => const Color(0x2E000000);

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
    loginBackgroundGlow: Color(0xFF375C78),
    drawerBackground: Color(0xFF191C1F),
    ink: Color(0xFFF2F6F9),
    accent: Color(0xFF68BDF9),
    accentBright: Color(0xFFA9EDFD),
    card: Color(0xFF272D32),
    cardBorder: Color(0xFF343D44),
    surfaceMuted: Color(0xFF2F373D),
    surfaceMutedBorder: Color(0xFF3D474E),
    inputBar: Color(0xFF252A31),
    inputBarBorder: Color(0xFF4E5963),
    userBubble: Color(0xFF1A1C22),
    userBubbleBorder: Color(0xFFD8D8D8),
    chatSendButton: Color(0xFF309AE6),
    quietText: Color(0xFF4CD980),
    quietChart: Color(0xFF25B34B),
    normalText: Color(0xFFF2C94C),
    normalChart: Color(0xFFD9A318),
    busyText: Color(0xFFEF8D5A),
    busyChart: Color(0xFFC8561D),
    kakaoContainer: Color(0xFFFEE500),
    kakaoSymbol: Color(0xFF000000),
    loginHeadlineGradientStart: Color(0xFFA3F1F9),
    loginHeadlineGradientMid: Color(0xFF6FC1FC),
    loginHeadlineGradientEnd: Color(0xFF309AE6),
    loginSubheadline: Color(0xFF7D8899),
    voiceListeningHint: Color(0xFF737B87),
    graphite: Color(0xFF292C36),
    crowdChartBackground: Color(0xFF333743),
    mapSheetGradientEnd: Color(0xFF17191F),
    dateFilterActiveBackground: Color(0xFF343843),
    toastBorder: Color(0xFFE4E4E4),
    alternativeReasonText: Color(0xFF698EA8),
    congestionQuiet: Color(0xFF15B836),
    congestionNormal: Color(0xFFD3A418),
    congestionBusy: Color(0xFFB84B15),
    chatCardAccent: Color(0xFF46A8EE),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? dark;
  }

  @override
  AppColors copyWith({
    Color? paper,
    Color? loginBackground,
    Color? loginBackgroundGlow,
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
    Color? userBubbleBorder,
    Color? chatSendButton,
    Color? quietText,
    Color? quietChart,
    Color? normalText,
    Color? normalChart,
    Color? busyText,
    Color? busyChart,
    Color? kakaoContainer,
    Color? kakaoSymbol,
    Color? loginHeadlineGradientStart,
    Color? loginHeadlineGradientMid,
    Color? loginHeadlineGradientEnd,
    Color? loginSubheadline,
    Color? voiceListeningHint,
    Color? graphite,
    Color? crowdChartBackground,
    Color? mapSheetGradientEnd,
    Color? dateFilterActiveBackground,
    Color? toastBorder,
    Color? alternativeReasonText,
    Color? congestionQuiet,
    Color? congestionNormal,
    Color? congestionBusy,
    Color? chatCardAccent,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      loginBackground: loginBackground ?? this.loginBackground,
      loginBackgroundGlow: loginBackgroundGlow ?? this.loginBackgroundGlow,
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
      userBubbleBorder: userBubbleBorder ?? this.userBubbleBorder,
      chatSendButton: chatSendButton ?? this.chatSendButton,
      quietText: quietText ?? this.quietText,
      quietChart: quietChart ?? this.quietChart,
      normalText: normalText ?? this.normalText,
      normalChart: normalChart ?? this.normalChart,
      busyText: busyText ?? this.busyText,
      busyChart: busyChart ?? this.busyChart,
      kakaoContainer: kakaoContainer ?? this.kakaoContainer,
      kakaoSymbol: kakaoSymbol ?? this.kakaoSymbol,
      loginHeadlineGradientStart:
          loginHeadlineGradientStart ?? this.loginHeadlineGradientStart,
      loginHeadlineGradientMid:
          loginHeadlineGradientMid ?? this.loginHeadlineGradientMid,
      loginHeadlineGradientEnd:
          loginHeadlineGradientEnd ?? this.loginHeadlineGradientEnd,
      loginSubheadline: loginSubheadline ?? this.loginSubheadline,
      voiceListeningHint: voiceListeningHint ?? this.voiceListeningHint,
      graphite: graphite ?? this.graphite,
      crowdChartBackground: crowdChartBackground ?? this.crowdChartBackground,
      mapSheetGradientEnd: mapSheetGradientEnd ?? this.mapSheetGradientEnd,
      dateFilterActiveBackground:
          dateFilterActiveBackground ?? this.dateFilterActiveBackground,
      toastBorder: toastBorder ?? this.toastBorder,
      alternativeReasonText:
          alternativeReasonText ?? this.alternativeReasonText,
      congestionQuiet: congestionQuiet ?? this.congestionQuiet,
      congestionNormal: congestionNormal ?? this.congestionNormal,
      congestionBusy: congestionBusy ?? this.congestionBusy,
      chatCardAccent: chatCardAccent ?? this.chatCardAccent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      loginBackground: Color.lerp(loginBackground, other.loginBackground, t)!,
      loginBackgroundGlow:
          Color.lerp(loginBackgroundGlow, other.loginBackgroundGlow, t)!,
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
      userBubbleBorder:
          Color.lerp(userBubbleBorder, other.userBubbleBorder, t)!,
      chatSendButton: Color.lerp(chatSendButton, other.chatSendButton, t)!,
      quietText: Color.lerp(quietText, other.quietText, t)!,
      quietChart: Color.lerp(quietChart, other.quietChart, t)!,
      normalText: Color.lerp(normalText, other.normalText, t)!,
      normalChart: Color.lerp(normalChart, other.normalChart, t)!,
      busyText: Color.lerp(busyText, other.busyText, t)!,
      busyChart: Color.lerp(busyChart, other.busyChart, t)!,
      kakaoContainer: Color.lerp(kakaoContainer, other.kakaoContainer, t)!,
      kakaoSymbol: Color.lerp(kakaoSymbol, other.kakaoSymbol, t)!,
      loginHeadlineGradientStart: Color.lerp(
          loginHeadlineGradientStart, other.loginHeadlineGradientStart, t)!,
      loginHeadlineGradientMid: Color.lerp(
          loginHeadlineGradientMid, other.loginHeadlineGradientMid, t)!,
      loginHeadlineGradientEnd: Color.lerp(
          loginHeadlineGradientEnd, other.loginHeadlineGradientEnd, t)!,
      loginSubheadline:
          Color.lerp(loginSubheadline, other.loginSubheadline, t)!,
      voiceListeningHint:
          Color.lerp(voiceListeningHint, other.voiceListeningHint, t)!,
      graphite: Color.lerp(graphite, other.graphite, t)!,
      crowdChartBackground:
          Color.lerp(crowdChartBackground, other.crowdChartBackground, t)!,
      mapSheetGradientEnd:
          Color.lerp(mapSheetGradientEnd, other.mapSheetGradientEnd, t)!,
      dateFilterActiveBackground: Color.lerp(
          dateFilterActiveBackground, other.dateFilterActiveBackground, t)!,
      toastBorder: Color.lerp(toastBorder, other.toastBorder, t)!,
      alternativeReasonText:
          Color.lerp(alternativeReasonText, other.alternativeReasonText, t)!,
      congestionQuiet: Color.lerp(congestionQuiet, other.congestionQuiet, t)!,
      congestionNormal:
          Color.lerp(congestionNormal, other.congestionNormal, t)!,
      congestionBusy: Color.lerp(congestionBusy, other.congestionBusy, t)!,
      chatCardAccent: Color.lerp(chatCardAccent, other.chatCardAccent, t)!,
    );
  }
}
