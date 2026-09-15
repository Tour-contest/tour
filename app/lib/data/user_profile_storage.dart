import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 성공 시 SNS SDK(현재는 카카오만)가 돌려준 프로필 정보(닉네임/프로필
/// 사진 URL/이메일)를 기기에 저장한다. `login_preference.dart`(마지막 로그인
/// 수단)와 같은 목적의 가벼운 영속화 패턴을 따른다 — 민감 정보가 아니라
/// `flutter_secure_storage`(`auth_token_storage.dart`) 대신 `shared_preferences`를
/// 쓴다. 셋 중 하나라도 없으면(동의하지 않았거나 조회 실패) 저장하지 않고, 읽는
/// 쪽(`settings_screen.dart`)이 `null`을 `DemoUser` 목업으로 대체한다.
class UserProfile {
  const UserProfile({
    this.nickname,
    this.profileImageUrl,
    this.email,
    this.isAdmin = false,
  });

  final String? nickname;
  final String? profileImageUrl;
  final String? email;

  /// `AuthService.loginAdmin`(관리자 로컬 로그인) 응답의 `user.role`이
  /// `admin`이면 `true`로 저장된다. `settings_screen.dart`가 이 값으로 관리자
  /// 계정의 "회원 탈퇴" 버튼을 비활성화하는 데 쓴다(관리자는 카카오 연결
  /// 해제를 함께 처리하는 `DELETE /api/v1/me` 탈퇴 흐름의 대상이 아님).
  final bool isAdmin;
}

class UserProfileStorage {
  UserProfileStorage._();

  static const _nicknameKey = 'sns_profile_nickname';
  static const _imageUrlKey = 'sns_profile_image_url';
  static const _emailKey = 'sns_profile_email';
  static const _isAdminKey = 'sns_profile_is_admin';

  static Future<void> save({
    String? nickname,
    String? profileImageUrl,
    String? email,
    bool isAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (nickname == null) {
      await prefs.remove(_nicknameKey);
    } else {
      await prefs.setString(_nicknameKey, nickname);
    }
    if (profileImageUrl == null) {
      await prefs.remove(_imageUrlKey);
    } else {
      await prefs.setString(_imageUrlKey, profileImageUrl);
    }
    if (email == null) {
      await prefs.remove(_emailKey);
    } else {
      await prefs.setString(_emailKey, email);
    }
    await prefs.setBool(_isAdminKey, isAdmin);
  }

  static Future<UserProfile?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString(_nicknameKey);
    final profileImageUrl = prefs.getString(_imageUrlKey);
    final email = prefs.getString(_emailKey);
    if (nickname == null && profileImageUrl == null && email == null) {
      return null;
    }
    return UserProfile(
      nickname: nickname,
      profileImageUrl: profileImageUrl,
      email: email,
      isAdmin: prefs.getBool(_isAdminKey) ?? false,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nicknameKey);
    await prefs.remove(_imageUrlKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_isAdminKey);
  }
}
