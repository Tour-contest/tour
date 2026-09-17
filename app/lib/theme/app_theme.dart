import 'package:flutter/material.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final colors = AppColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.paper,
      fontFamily: AppTextStyles.body(color: colors.ink).fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: Brightness.dark,
        surface: colors.paper,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accentTint14,
        selectionHandleColor: colors.accent,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: colors.divider,
      extensions: [colors],
    );
  }
}
