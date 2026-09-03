import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/onboarding_screen.dart';
import 'package:nullnull/theme/app_locale_controller.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_theme.dart';
import 'package:nullnull/widgets/network_status_listener.dart';

late final AppTextScaleController appTextScaleController;
late final AppLocaleController appLocaleController;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.ensureInitialized();
  appTextScaleController = await AppTextScaleController.ensureInitialized();
  appLocaleController = await AppLocaleController.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const NullnullApp());
}

class NullnullApp extends StatelessWidget {
  const NullnullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocaleOption>(
      valueListenable: appLocaleController,
      builder: (context, localeOption, _) {
        return ValueListenableBuilder<AppFontScale>(
          valueListenable: appTextScaleController,
          builder: (context, scale, _) {
            return MaterialApp(
              navigatorKey: _rootNavigatorKey,
              title: '널널',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.theme,
              locale: localeOption.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // locale이 null(시스템 언어 옵션)일 때만 적용된다. 지원하지 않는
              // 기기 로케일은 한국어(제품 기본 언어)로 대체한다.
              localeResolutionCallback: (locale, supportedLocales) {
                for (final supported in supportedLocales) {
                  if (supported.languageCode == locale?.languageCode) {
                    return supported;
                  }
                }
                return const Locale('ko');
              },
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(scale.factor),
                  ),
                  child: NetworkStatusListener(
                    navigatorKey: _rootNavigatorKey,
                    child: child!,
                  ),
                );
              },
              home: const OnboardingScreen(),
            );
          },
        );
      },
    );
  }
}
