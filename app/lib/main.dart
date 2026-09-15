import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_info.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/crash_reporting_service.dart';
import 'package:nullnull/firebase_options.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_locale_controller.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_theme.dart';
import 'package:nullnull/widgets/health_check_gate.dart';
import 'package:nullnull/widgets/network_status_listener.dart';

late final AppTextScaleController appTextScaleController;
late final AppLocaleController appLocaleController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CrashReportingService.ensureInitialized();
  await AppInfo.ensureInitialized();
  appTextScaleController = await AppTextScaleController.ensureInitialized();
  appLocaleController = await AppLocaleController.ensureInitialized();
  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey, loggingEnabled: true);

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
            return MaterialApp.router(
              routerConfig: appRouter,
              title: '널널',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.theme,
              locale: localeOption.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(scale.factor),
                  ),
                  child: HealthCheckGate(
                    navigatorKey: rootNavigatorKey,
                    child: NetworkStatusListener(
                      navigatorKey: rootNavigatorKey,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        child: child,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
