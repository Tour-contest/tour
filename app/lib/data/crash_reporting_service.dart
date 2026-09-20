import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Crashlytics 초기화를 감싼 유틸리티. `main.dart`에서
/// `Firebase.initializeApp()` 직후 `ensureInitialized()`를 호출해, Flutter
/// 프레임워크 에러와 처리되지 않은 Dart 에러를 모두 Crashlytics로 보낸다.
/// 디버그 빌드에서는 수집을 끈다(로컬 개발 중 크래시는 콘솔/디버거로 충분).
class CrashReportingService {
  CrashReportingService._();

  static Future<void> ensureInitialized() async {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
