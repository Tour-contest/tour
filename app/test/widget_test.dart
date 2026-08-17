import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/theme/app_theme_controller.dart';

void main() {
  setUpAll(() async {
    // 테스트 환경에서는 네트워크로 폰트를 내려받지 않고 로컬 폴백만 사용한다.
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '널널',
      packageName: 'kr.co.nullnull',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppInfo.ensureInitialized();
    appThemeController = await AppThemeController.ensureInitialized();
  });

  testWidgets('온보딩에서 채팅으로, 새 대화에서 지난 대화로 이동한다', (WidgetTester tester) async {
    await tester.pumpWidget(const NullnullApp());

    expect(find.text('널널'), findsOneWidget);
    expect(find.text('여행 시작하기'), findsOneWidget);

    await tester.tap(find.text('여행 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('이번 여행,\n조금 더 널널하게 가볼까요?'), findsOneWidget);

    await tester.tap(find.byTooltip('지난 대화'));
    await tester.pumpAndSettle();

    expect(find.text('지난 대화'), findsWidgets);

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    expect(find.text('화면 모드'), findsOneWidget);
    expect(find.text('1.0.0 (1)'), findsOneWidget);
  });
}
