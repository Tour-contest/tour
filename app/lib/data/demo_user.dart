import 'package:nullnull/data/login_preference.dart';

/// 설정 화면의 "내 정보"에 보여줄 데모용 프로필 데이터.
/// 실제 계정/회원 시스템 연동 전 단계로, 로그인에 사용한 SNS 수단에 맞춰
/// 고정된 닉네임/이메일을 보여준다. `demo_script.dart`와 마찬가지로
/// `BuildContext` 없는 순수 Dart 데이터라 `AppLocalizations` 대신 화면이
/// 넘겨주는 `languageCode`로 닉네임의 한국어/영어 버전을 고른다.
class DemoUser {
  DemoUser._();

  static const _nicknamesKo = {
    SnsProvider.kakao: '널널한 여행자',
    SnsProvider.naver: '한적한 나그네',
  };

  static const _nicknamesEn = {
    SnsProvider.kakao: 'Easygoing Traveler',
    SnsProvider.naver: 'Quiet Wanderer',
  };

  static const _maskedEmails = {
    SnsProvider.kakao: 'travel****@kakao.com',
    SnsProvider.naver: 'travel****@naver.com',
  };

  static String nicknameFor(SnsProvider provider, [String languageCode = 'ko']) {
    final nicknames = languageCode == 'en' ? _nicknamesEn : _nicknamesKo;
    return nicknames[provider]!;
  }

  static String maskedEmailFor(SnsProvider provider) =>
      _maskedEmails[provider]!;
}
