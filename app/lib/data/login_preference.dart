import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면에서 지원하는 SNS 로그인/회원가입 수단.
enum SnsProvider { kakao, naver }

/// 로그인 화면의 "최근 로그인" 뱃지 표시를 위해 마지막으로 사용한 SNS 로그인
/// 수단을 기기에 저장한다. 프로토타입 단계로 실제 SNS 인증 연동은 없다.
class LoginPreference {
  LoginPreference._();

  static const _prefsKey = 'last_login_provider';

  static Future<SnsProvider?> readLastProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    for (final provider in SnsProvider.values) {
      if (provider.name == stored) return provider;
    }
    return null;
  }

  static Future<void> saveLastProvider(SnsProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, provider.name);
  }
}
