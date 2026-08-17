import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _themeFor(AppColors.light, Brightness.light);
  static ThemeData get dark => _themeFor(AppColors.dark, Brightness.dark);

  static ThemeData _themeFor(AppColors colors, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.paper,
      fontFamily: AppTextStyles.body(color: colors.ink).fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.gold,
        brightness: brightness,
        surface: colors.paper,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.gold,
        selectionColor: colors.goldTint14,
        selectionHandleColor: colors.gold,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: colors.divider,
      extensions: [colors],
    );
  }
}
