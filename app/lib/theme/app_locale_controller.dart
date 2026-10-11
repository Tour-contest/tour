import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 화면 "언어" 섹션의 수동 전환 옵션. 한국어/영어 2개만 지원하므로
/// 기기 언어를 따르는 옵션은 두지 않는다.
enum AppLocaleOption {
  korean(Locale('ko')),
  english(Locale('en'));

  const AppLocaleOption(this.locale);

  final Locale locale;
}

/// 설정 화면의 "언어" 선택을 `shared_preferences`에 영속화한다
/// (`app_text_scale_controller.dart`와 동일한 패턴).
class AppLocaleController extends ValueNotifier<AppLocaleOption> {
  AppLocaleController._(super.initial);

  static const _prefsKey = 'app_locale_option';

  static Future<AppLocaleController> ensureInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    return AppLocaleController._(_decode(stored));
  }

  Future<void> setOption(AppLocaleOption option) async {
    value = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, option.name);
  }

  static AppLocaleOption _decode(String? raw) {
    return AppLocaleOption.values.firstWhere(
      (option) => option.name == raw,
      orElse: () => AppLocaleOption.korean,
    );
  }
}
