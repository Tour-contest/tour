import 'package:dio/dio.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/auth_token_storage.dart';

/// 로그인/토큰 교환/갱신/로그아웃 요청이 실패(`success: false`)했을 때
/// 던지는 예외.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `docs/API_SPEC.md`의 `auth` 절 연동. 카카오 소셜 로그인 교환·토큰 갱신·
/// 로그아웃이 구현돼 있다(로그인 작업 2·4·5단계). `lib/api/api_client.dart`의
/// `ApiClient.create()`(`Authorization` 헤더 자동 부착 + 401 시 이 클래스의
/// [refresh]를 호출) 대신 매번 순수 [Dio]를 직접 만들어 쓴다 — `ApiClient`가
/// 401 처리를 위해 이 클래스를 참조해야 해서, 반대로 이 클래스가 `ApiClient`를
/// 참조하면 순환 의존이 생기기 때문이다([logout]처럼 인증이 필요한 엔드포인트도
/// 저장된 토큰을 직접 읽어 헤더에 실어 보내는 식으로 우회한다).
class AuthService {
  AuthService._();

  static Dio _plainDio() => Dio(BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
      ));

  /// `POST /api/v1/auth/oauth/kakao/callback`. 카카오 SDK로 받은
  /// [kakaoAccessToken]을 백엔드에 보내 우리 서비스의 access/refresh 토큰으로
  /// 교환하고, 성공하면 [AuthTokenStorage]에 저장까지 한다. 응답 `data`의
  /// 필드명은 명세서에 예시 페이로드가 없어 `### 인증` 절 설명 문구("로그인
  /// 응답의 `access_token`")를 근거로 `access_token`/`refresh_token`으로
  /// 가정했다(확정되면 이 함수만 갱신하면 됨) — 실기기 로그인으로 이 가정이
  /// 실제 응답과 맞음을 확인함.
  static Future<void> loginWithKakao(String kakaoAccessToken) async {
    final response = await _plainDio().post<Map<String, dynamic>>(
      AppConfig.authOAuthCallbackEndpoint('kakao'),
      data: {'access_token': kakaoAccessToken},
    );
    final envelope = response.data;
    if (envelope?['success'] != true) {
      throw AuthException(envelope?['message'] as String? ?? '로그인에 실패했어요.');
    }
    final data = envelope?['data'] as Map<String, dynamic>? ?? const {};
    await AuthTokenStorage.save(AuthTokens(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String? ?? '',
    ));
  }

  static Future<AuthTokens>? _refreshInFlight;

  /// `POST /api/v1/auth/refresh`. `ApiClient`의 인증 인터셉터가 401을 받았을
  /// 때 호출한다. `docs/API_SPEC.md`의 "갱신 요청을 동시에 여러 개 보내면
  /// 안 됨" 규칙에 따라, 이미 진행 중인 갱신이 있으면 새로 요청을 보내지
  /// 않고 그 결과를 함께 기다린다(정적 필드로 앱 전체에서 공유).
  /// 실패(리프레시 토큰 재사용/만료 등)하면 [AuthTokenStorage]를 비우고
  /// [AuthException]을 던진다 — 화면 이동(로그인 화면으로) 같은 세션 만료
  /// 후속 처리는 아직 없고, 저장된 토큰만 지워 다음 요청부터 다시 401이
  /// 나지 않게(빈 상태로) 정리하는 수준이다.
  static Future<AuthTokens> refresh() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<AuthTokens> _performRefresh() async {
    final current = await AuthTokenStorage.read();
    if (current == null) {
      throw AuthException('로그인이 필요해요.');
    }
    try {
      final response = await _plainDio().post<Map<String, dynamic>>(
        AppConfig.authRefreshEndpoint,
        data: {'refresh_token': current.refreshToken},
      );
      final envelope = response.data;
      if (envelope?['success'] != true) {
        await AuthTokenStorage.clear();
        throw AuthException(
            envelope?['message'] as String? ?? '세션이 만료됐어요. 다시 로그인해주세요.');
      }
      final data = envelope?['data'] as Map<String, dynamic>? ?? const {};
      final tokens = AuthTokens(
        accessToken: data['access_token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String? ?? '',
      );
      await AuthTokenStorage.save(tokens);
      return tokens;
    } on DioException catch (e) {
      // 서버가 리프레시 토큰을 거절한 경우(재사용/만료 등)만 로컬 토큰을
      // 지운다. 타임아웃 등 네트워크 오류는 다음에 다시 시도할 수 있게 그대로
      // 둔다.
      if (e.response != null) {
        await AuthTokenStorage.clear();
      }
      rethrow;
    }
  }

  /// `POST /api/v1/auth/logout`(인증 필요, 리프레시 토큰 전체 폐기). 저장된
  /// 토큰이 없으면(이미 로그아웃 상태이거나 애초에 백엔드 로그인을 한 적
  /// 없는 네이버 mock 로그인 등) 요청 없이 곧바로 반환한다. 요청이 실패해도
  /// (네트워크 오류 등) 로컬 로그아웃은 항상 진행해야 하므로 로깅만 하고
  /// 계속 진행한다 — `logout_service.dart`가 카카오 SDK 로그아웃 실패를
  /// 다루는 것과 동일한 방식. 성공/실패와 무관하게 마지막에 항상
  /// [AuthTokenStorage.clear]로 로컬 토큰을 지운다.
  static Future<void> logout() async {
    final tokens = await AuthTokenStorage.read();
    if (tokens != null) {
      try {
        await _plainDio().post<Map<String, dynamic>>(
          AppConfig.authLogoutEndpoint,
          options: Options(
            headers: {'Authorization': 'Bearer ${tokens.accessToken}'},
          ),
        );
      } catch (e, stackTrace) {
        AppLog.logger
            .e('로그아웃 요청 실패(로컬 토큰은 삭제됨)', error: e, stackTrace: stackTrace);
      }
    }
    await AuthTokenStorage.clear();
  }

  /// `DELETE /api/v1/me`. 회원 탈퇴(카카오 연결 해제까지 서버가 함께 처리,
  /// `docs/API_SPEC.md` 참고) — `settings_screen.dart`의 "연결 끊기"가 호출한다.
  /// [logout]과 달리 실패해도 로컬 토큰을 지우지 않는다 — 계정이 실제로
  /// 지워지지 않았는데 로그아웃 상태로 보이면 다시 로그인해야 하는 등 혼란만
  /// 커지므로, 실패는 [AuthException]으로 알려 호출부가 재시도 안내만 하게
  /// 한다. 성공하면 계정 자체가 없어졌으므로 로컬 토큰도 지운다.
  static Future<void> withdraw() async {
    final tokens = await AuthTokenStorage.read();
    if (tokens == null) {
      throw AuthException('로그인이 필요해요.');
    }
    final response = await _plainDio().delete<Map<String, dynamic>>(
      AppConfig.meEndpoint,
      options: Options(
        headers: {'Authorization': 'Bearer ${tokens.accessToken}'},
      ),
    );
    final envelope = response.data;
    if (envelope?['success'] != true) {
      throw AuthException(envelope?['message'] as String? ?? '연결 끊기에 실패했어요.');
    }
    await AuthTokenStorage.clear();
  }
}
