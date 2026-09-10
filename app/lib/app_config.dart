/// 백엔드/외부 서비스 연동 설정. [baseUrl]/[healthzEndpoint]/[attributionEndpoint]는
/// `docs/API_SPEC.md`로 확정된 실제 값이다. [chatMessageEndpoint]/[congestionEndpoint]/
/// [alternativesEndpoint]는 아직 이 문서에 경로가 정리되지 않아 `docs/design_handoff_storyboard.md`에
/// 언급된 기능 ID(F-01 등)를 근거로 임시로 붙여 둔 플레이스홀더다(확정된 [healthzEndpoint]처럼
/// `/api/v1` 프리픽스가 붙을 가능성이 높으니, `docs/API_SPEC.md`에 해당 섹션이 채워지면 실제
/// 값으로 교체할 것).
class AppConfig {
  AppConfig._();

  static const String baseUrl = 'https://nullnull.kr';

  static const Duration apiTimeout = Duration(seconds: 10);

  static const String healthzEndpoint = '/api/v1/healthz';

  static const String attributionEndpoint = '/api/v1/meta/attribution';

  static const String chatMessageEndpoint = '/v1/chat/messages';

  static const String congestionEndpoint = '/v1/congestion';

  static const String alternativesEndpoint = '/v1/places/alternatives';

  /// 카카오 로그인 SDK(`kakao_flutter_sdk_user`) 초기화용 네이티브 앱 키.
  /// 카카오 디벨로퍼스 콘솔(내 애플리케이션 > 앱 키)에서 발급받은 값.
  static const String kakaoNativeAppKey = '7f60a3b500adcd2836dd7a5ce7411a0c';
}
