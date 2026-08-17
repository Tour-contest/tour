import 'package:flutter/material.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/screens/onboarding_screen.dart';
import 'package:nullnull/theme/app_theme.dart';
import 'package:nullnull/theme/app_theme_controller.dart';

late final AppThemeController appThemeController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.ensureInitialized();
  appThemeController = await AppThemeController.ensureInitialized();
  runApp(const NullnullApp());
}

class NullnullApp extends StatelessWidget {
  const NullnullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: '널널',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const OnboardingScreen(),
        );
      },
    );
  }
}
