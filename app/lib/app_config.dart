/// 백엔드/외부 서비스 연동 설정. 아직 자체 API 연동 명세서가 확정되지 않아 [baseUrl]과
/// 엔드포인트 경로는 모두 플레이스홀더이며, `docs/design_handoff_storyboard.md`에 언급된
/// 기능 ID(F-01 등)를 근거로 임시로 붙여 두었다. 명세서가 나오면 실제 값으로 교체한다.
class AppConfig {
  AppConfig._();

  /// TODO 실제 API 서버 주소로 교체
  static const String baseUrl = 'https://api.nullnull.example.com';

  static const Duration apiTimeout = Duration(seconds: 10);

  /// 채팅 메시지 전송 · AI 응답 조회 (F-08/F-09)
  static const String chatMessageEndpoint = '/v1/chat/messages';

  /// 혼잡도 조회 (F-01/F-05)
  static const String congestionEndpoint = '/v1/congestion';

  /// 대안 장소 추천 (F-02)
  static const String alternativesEndpoint = '/v1/places/alternatives';

  /// 카카오 로그인 SDK(`kakao_flutter_sdk_user`) 초기화용 네이티브 앱 키.
  /// 카카오 디벨로퍼스 콘솔(내 애플리케이션 > 앱 키)에서 발급받은 값.
  static const String kakaoNativeAppKey = '7f60a3b500adcd2836dd7a5ce7411a0c';
}
