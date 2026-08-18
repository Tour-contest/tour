import 'package:flutter/material.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/screens/onboarding_screen.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_theme.dart';

late final AppTextScaleController appTextScaleController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.ensureInitialized();
  appTextScaleController = await AppTextScaleController.ensureInitialized();
  runApp(const NullnullApp());
}

class NullnullApp extends StatelessWidget {
  const NullnullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppFontScale>(
      valueListenable: appTextScaleController,
      builder: (context, scale, _) {
        return MaterialApp(
          title: '널널',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(scale.factor),
              ),
              child: child!,
            );
          },
          home: const OnboardingScreen(),
        );
      },
    );
  }
}
