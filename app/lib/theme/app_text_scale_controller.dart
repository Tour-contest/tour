import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 접근성을 위한 글자 크기 단계. `factor`는 [MediaQuery]의 `textScaler`에
/// 곱해져 앱 전체 텍스트 크기에 적용된다.
enum AppFontScale {
  small(0.9, '작게'),
  normal(1.0, '보통'),
  large(1.15, '크게'),
  extraLarge(1.3, '아주 크게');

  const AppFontScale(this.factor, this.label);

  final double factor;
  final String label;
}

/// 설정 화면의 "글자 크기" 선택을 `shared_preferences`에 영속화한다.
class AppTextScaleController extends ValueNotifier<AppFontScale> {
  AppTextScaleController._(super.initial);

  static const _prefsKey = 'app_font_scale';

  static Future<AppTextScaleController> ensureInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    return AppTextScaleController._(_decode(stored));
  }

  Future<void> setScale(AppFontScale scale) async {
    value = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, scale.name);
  }

  static AppFontScale _decode(String? raw) {
    return AppFontScale.values.firstWhere(
      (scale) => scale.name == raw,
      orElse: () => AppFontScale.normal,
    );
  }
}
