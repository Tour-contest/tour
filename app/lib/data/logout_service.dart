import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/auth_service.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/data/user_profile_storage.dart';

/// SNS 로그인 수단별 로그아웃 SDK 호출을 한 곳에 모아 `SettingsScreen`의
/// "로그아웃" 버튼과 채팅 화면 헤더의 프로필 메뉴 "로그아웃"이 동일한 동작을
/// 공유하도록 한다. 어느 provider든 먼저 `AuthService.logout()`으로 우리
/// 백엔드 세션을 정리(`POST /api/v1/auth/logout` + `AuthTokenStorage.clear()`,
/// 저장된 토큰이 없으면 — 네이버 mock 로그인처럼 — 조용히 스킵)하고
/// `UserProfileStorage.clear()`로 저장해둔 닉네임/프로필 사진도 지운 뒤,
/// 카카오라면 SDK 로그아웃도 호출한다. 실패는 로깅만 하고 계속 진행한다
/// (기기에 저장된 토큰은 각 SDK/스토리지 내부에서 이미 삭제됨).
class LogoutService {
  LogoutService._();

  static Future<void> logout(SnsProvider provider) async {
    await AuthService.logout();
    await UserProfileStorage.clear();
    if (provider != SnsProvider.kakao) return;
    try {
      await UserApi.instance.logout();
      AppLog.logger.i('카카오 로그아웃 성공');
    } catch (error) {
      AppLog.logger.e('카카오 로그아웃 실패(기기에 저장된 토큰은 삭제됨)', error: error);
    }
  }
}
