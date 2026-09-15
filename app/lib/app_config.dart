/// 백엔드/외부 서비스 연동 설정. [baseUrl]/[healthzEndpoint]/[attributionEndpoint]와
/// `chat*Endpoint`/`auth*Endpoint`/`area*Endpoint`/`attraction*Endpoint` 계열은
/// `docs/API_SPEC.md`로 확정된 실제 값이다.
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

  /// 관리자 로컬 로그인(아이디/비밀번호). 5회 연속 실패 시 10분 잠금
  /// (`docs/API_SPEC.md`). 로그인 화면 하단의 숨겨진 관리자 로그인 버튼에서
  /// 사용한다.
  static const String authLoginEndpoint = '/api/v1/auth/login';

  /// 토큰 갱신(리프레시 회전). 인증 불필요(요청 바디의 리프레시 토큰으로 인증).
  static const String authRefreshEndpoint = '/api/v1/auth/refresh';

  /// 로그아웃(리프레시 토큰 전체 폐기). 인증 필요.
  static const String authLogoutEndpoint = '/api/v1/auth/logout';

  /// 내 정보 조회(`GET`)/회원 탈퇴(`DELETE`, 카카오 연결 해제 포함). 인증 필요.
  static const String meEndpoint = '/api/v1/me';

  /// 시도별 시군구 전체 목록(캐시 가능한 기준정보).
  static const String areasEndpoint = '/api/v1/areas';

  /// 지역명 → 코드 변환.
  static const String areasResolveEndpoint = '/api/v1/areas/resolve';

  static String areaOverviewEndpoint(String signguCd) =>
      '/api/v1/areas/$signguCd/overview';

  static String areaCrowdingEndpoint(String signguCd) =>
      '/api/v1/areas/$signguCd/crowding';

  static String areaVisitorsEndpoint(String signguCd) =>
      '/api/v1/areas/$signguCd/visitors';

  static const String attractionsSearchEndpoint = '/api/v1/attractions/search';

  static String attractionEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId';

  static String attractionCrowdEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId/crowd';

  static String attractionAlternativesEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId/alternatives';

  static String attractionInterestEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId/interest';

  static String attractionImagesEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId/images';

  static String attractionPetEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId/pet';

  static String attractionSimilarEndpoint(String contentId) =>
      '/api/v1/attractions/$contentId/similar';

  /// 최근 본 관광지 목록 조회(`GET`)/전체 삭제(`DELETE`, 개별 삭제 없음).
  static const String recentAttractionsEndpoint =
      '/api/v1/me/recent-attractions';

  /// 카카오 로그인 SDK(`kakao_flutter_sdk_user`) 초기화용 네이티브 앱 키.
  /// 카카오 디벨로퍼스 콘솔(내 애플리케이션 > 앱 키)에서 발급받은 값.
  static const String kakaoNativeAppKey = '7f60a3b500adcd2836dd7a5ce7411a0c';
}
