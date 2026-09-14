import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/screens/chat_screen.dart';
import 'package:nullnull/screens/history_screen.dart';
import 'package:nullnull/screens/login_screen.dart';
import 'package:nullnull/screens/onboarding_screen.dart';
import 'package:nullnull/screens/place_detail_screen.dart';
import 'package:nullnull/screens/attraction_detail_screen.dart';
import 'package:nullnull/screens/settings_screen.dart';
import 'package:nullnull/screens/splash_screen.dart';
import 'package:nullnull/screens/web_view_screen.dart';

/// 앱 전역 라우터의 [Navigator]에 접근하기 위한 키. [NetworkStatusListener]가
/// 오프라인 팝업을 띄울 오버레이 컨텍스트를 얻는 데 사용한다.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// [GoRoute.name] 상수. 경로 문자열을 화면 코드 곳곳에 하드코딩하지 않도록
/// `context.pushNamed`/`goNamed` 호출 시 이 값을 쓴다.
class RouteNames {
  RouteNames._();

  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const chat = 'chat';
  static const history = 'history';
  static const settings = 'settings';
  static const place = 'place';
  static const webView = 'webView';
  static const attractionDetail = 'attractionDetail';
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/${RouteNames.splash}',
  observers: [AnalyticsService.observer],
  routes: [
    GoRoute(
      path: '/${RouteNames.splash}',
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/${RouteNames.onboarding}',
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/${RouteNames.login}',
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/${RouteNames.chat}',
      name: RouteNames.chat,
      builder: (context, state) =>
          ChatScreen(resume: state.extra as ChatResumeData?),
    ),
    GoRoute(
      path: '/${RouteNames.history}',
      name: RouteNames.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/${RouteNames.settings}',
      name: RouteNames.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/${RouteNames.place}',
      name: RouteNames.place,
      builder: (context, state) =>
          PlaceDetailScreen(place: state.extra as PlaceRecommendation),
    ),
    GoRoute(
      path: '/${RouteNames.webView}',
      name: RouteNames.webView,
      builder: (context, state) {
        final args = state.extra as WebViewRouteArgs;
        return WebViewScreen(title: args.title, url: args.url);
      },
    ),
    GoRoute(
      path: '/${RouteNames.attractionDetail}',
      name: RouteNames.attractionDetail,
      builder: (context, state) {
        final args = state.extra as AttractionDetailArgs;
        return AttractionDetailScreen(
            contentId: args.contentId, initialTitle: args.initialTitle);
      },
    ),
  ],
);
