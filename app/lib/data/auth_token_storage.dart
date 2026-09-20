import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// `docs/API_SPEC.md`의 `### 인증` 규칙에 따른 토큰 한 쌍(액세스 30분/리프레시
/// 14일 유효). 리프레시는 사용할 때마다 새 값으로 회전하므로, 갱신 시에도 이
/// 클래스로 두 값을 함께 교체해야 한다.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// 액세스/리프레시 토큰을 iOS Keychain/Android Keystore(`flutter_secure_storage`)에
/// 저장하는 유틸리티. `shared_preferences`(평문 저장)를 쓰는 `login_preference.dart`
/// 등과 달리, 유출 시 계정을 탈취당할 수 있는 민감 정보라 별도로 분리했다.
class AuthTokenStorage {
  AuthTokenStorage._();

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  static Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }

  /// 저장된 토큰이 없으면(로그인 전, 로그아웃 후) `null`.
  static Future<AuthTokens?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) return null;
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
