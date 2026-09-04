import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/login_preference.dart';

/// Firebase Analytics 이벤트 로깅을 감싼 유틸리티.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// `app_router.dart`의 `GoRouter.observers`에 등록해 화면 전환을 자동으로 기록한다.
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> logLogin(SnsProvider provider) =>
      _analytics.logLogin(loginMethod: provider.name);

  static Future<void> logPlaceDetailView(PlaceRecommendation place) =>
      _analytics.logSelectContent(contentType: 'place', itemId: place.name);

  static Future<void> logChatMessageSent() =>
      _analytics.logEvent(name: 'chat_message_sent');
}
