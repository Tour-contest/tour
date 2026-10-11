import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';

class AppLog {
  AppLog._();

  static final Logger logger = Logger(
    printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 5,
        lineLength: 200,
        dateTimeFormat: DateTimeFormat.dateAndTime),
    output: MultiOutput([ConsoleOutput(), _CrashlyticsLogOutput()]),
  );
}

/// `AppLog.logger.e(...)`(또는 그 이상 레벨)로 남긴 로그를 콘솔 출력과 별개로
/// Crashlytics에도 non-fatal 이슈로 보낸다. `crash_reporting_service.dart`의
/// `FlutterError.onError`/`PlatformDispatcher.instance.onError`는 잡히지 않은
/// (uncaught) 에러만 다루기 때문에, `try/catch`로 이미 처리한 뒤 이 로거로만
/// 남기는 에러(카카오 로그인 실패 등 앱 전역의 거의 모든 에러 로그)는 이 출력이
/// 없으면 Crashlytics에 전혀 기록되지 않았다.
class _CrashlyticsLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (event.level < Level.error) return;
    // Firebase가 아직 초기화되지 않은 환경(위젯 테스트 등, `NullnullApp`을
    // 거치지 않고 화면만 단독으로 띄우는 경우 `[core/no-app]`)에서도 로깅
    // 유틸리티 자체가 죽으면 안 되므로 조용히 무시한다.
    try {
      FirebaseCrashlytics.instance
          .recordError(
            event.origin.error ?? event.origin.message,
            event.origin.stackTrace,
            reason: event.origin.message?.toString(),
            // `PrettyPrinter`(`ConsoleOutput`)가 이미 보기 좋게 콘솔에 찍어주므로,
            // Crashlytics 쪽의 중복 print(`printDetails` 기본값이 디버그 빌드에서
            // true)는 끈다.
            printDetails: false,
            fatal: false,
          )
          .catchError((_) {});
    } catch (_) {
      // ignore
    }
  }
}
