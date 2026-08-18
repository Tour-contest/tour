import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 스토어 스크린샷용 화면 전환 흐름.
///
/// `flutter test integration_test/screenshot_flow_test.dart -d <device>` 로 실행하면
/// 실제 기기/시뮬레이터 위에서 화면을 순서대로 전환한다. 각 화면에서
/// "SCREENSHOT_READY:`<name>`" 을 출력한 뒤 잠시 정지하므로, 그 사이에
/// 외부에서 `xcrun simctl io <device> screenshot` 등으로 캡처하면 된다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot flow', (tester) async {
    await AppInfo.ensureInitialized();
    appTextScaleController = await AppTextScaleController.ensureInitialized();
    await tester.pumpWidget(const NullnullApp());
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREENSHOT_READY:01_onboarding');
    await Future<void>.delayed(const Duration(seconds: 20));

    await tester.tap(find.text('여행 시작하기'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREENSHOT_READY:02_login');
    await Future<void>.delayed(const Duration(seconds: 20));

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREENSHOT_READY:03_chat_empty');
    await Future<void>.delayed(const Duration(seconds: 20));

    await tester.tap(find.text('이번 주말 전주 한옥마을 대신 갈 만한 곳'));
    await tester.pump();
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // ignore: avoid_print
    print('SCREENSHOT_READY:04_chat_conversation');
    await Future<void>.delayed(const Duration(seconds: 20));

    await tester.tap(find.byTooltip('지난 대화'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREENSHOT_READY:05_history');
    await Future<void>.delayed(const Duration(seconds: 20));

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREENSHOT_READY:06_settings');
    await Future<void>.delayed(const Duration(seconds: 20));
  });

  testWidgets('feature graphic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            final width = MediaQuery.sizeOf(context).width;
            final height = width * 500 / 1024;
            final topInset = MediaQuery.paddingOf(context).top + 24;
            final dpr = MediaQuery.devicePixelRatioOf(context);
            // ignore: avoid_print
            print(
              'GRAPHIC_BOX:top=${topInset * dpr},width=${width * dpr},height=${height * dpr}',
            );
            return Scaffold(
              backgroundColor: AppColors.light.ink,
              body: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.light.gold, width: 5),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '여유 · 쾌적 · 한적',
                              style: AppTextStyles.body(
                                fontSize: 9,
                                color: AppColors.light.gold,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '널널',
                              style: AppTextStyles.display(
                                  fontSize: 58, color: const Color(0xFFF3F2F2)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '한적한 여행을 안내하는 AI 여행 비서',
                              style: AppTextStyles.body(
                                  fontSize: 11, color: const Color(0xFFD9D6D2)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('SCREENSHOT_READY:05_feature_graphic');
    await Future<void>.delayed(const Duration(seconds: 20));
  });
}
