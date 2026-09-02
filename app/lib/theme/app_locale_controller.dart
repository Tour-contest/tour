import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정 화면 "언어" 섹션의 수동 전환 옵션. [locale]이 null이면 기기 로케일을
/// 따른다(지원하지 않는 로케일은 `main.dart`의 `localeResolutionCallback`으로
/// 한국어 폴백).
enum AppLocaleOption {
  system(null),
  korean(Locale('ko')),
  english(Locale('en'));

  const AppLocaleOption(this.locale);

  final Locale? locale;
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
      orElse: () => AppLocaleOption.system,
    );
  }
}
