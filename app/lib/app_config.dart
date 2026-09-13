/// 백엔드/외부 서비스 연동 설정. [baseUrl]/[healthzEndpoint]/[attributionEndpoint]와
/// `chat*Endpoint`/`auth*Endpoint` 계열은 `docs/API_SPEC.md`로 확정된 실제 값이다. [congestionEndpoint]/
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

  /// 대화 전송(SSE). 분당 10회 별도 제한.
  static const String chatStreamEndpoint = '/api/v1/chat/stream';

  static const String chatSessionsEndpoint = '/api/v1/chat/sessions';

  static String chatSessionMessagesEndpoint(String sessionId) =>
      '/api/v1/chat/sessions/$sessionId/messages';

  /// 끊긴 스트림 이어받기(새로고침 복구용).
  static String chatSessionStreamEndpoint(String sessionId) =>
      '/api/v1/chat/sessions/$sessionId/stream';

  static String chatSessionEndpoint(String sessionId) =>
      '/api/v1/chat/sessions/$sessionId';

  /// 소셜 로그인. `provider`는 `kakao`만 허용(`docs/API_SPEC.md`).
  static String authOAuthCallbackEndpoint(String provider) =>
      '/api/v1/auth/oauth/$provider/callback';

  /// 토큰 갱신(리프레시 회전). 인증 불필요(요청 바디의 리프레시 토큰으로 인증).
  static const String authRefreshEndpoint = '/api/v1/auth/refresh';

  /// 로그아웃(리프레시 토큰 전체 폐기). 인증 필요.
  static const String authLogoutEndpoint = '/api/v1/auth/logout';

  /// 내 정보 조회(`GET`)/회원 탈퇴(`DELETE`, 카카오 연결 해제 포함). 인증 필요.
  static const String meEndpoint = '/api/v1/me';

  static const String congestionEndpoint = '/v1/congestion';

  static const String alternativesEndpoint = '/v1/places/alternatives';

  /// 카카오 로그인 SDK(`kakao_flutter_sdk_user`) 초기화용 네이티브 앱 키.
  /// 카카오 디벨로퍼스 콘솔(내 애플리케이션 > 앱 키)에서 발급받은 값.
  static const String kakaoNativeAppKey = '7f60a3b500adcd2836dd7a5ce7411a0c';
}
