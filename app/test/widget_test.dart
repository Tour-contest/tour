import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/main.dart';
import 'package:nullnull/theme/app_locale_controller.dart';
import 'package:nullnull/theme/app_text_scale_controller.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '널널',
      packageName: 'kr.co.nullnull',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await AppInfo.ensureInitialized();
    appTextScaleController = await AppTextScaleController.ensureInitialized();
    appLocaleController = await AppLocaleController.ensureInitialized();
  });

  testWidgets('온보딩에서 로그인, 채팅으로, 새 대화에서 지난 대화로 이동한다',
      (WidgetTester tester) async {
    // 호스트/CI 환경 로케일과 무관하게 한국어 카피를 기준으로 검증한다.
    // Localizations는 plural locales 목록을 기준으로 해석하므로
    // localesTestValue를 설정해야 한다(localeTestValue만으로는 반영되지 않음).
    tester.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const NullnullApp());

    expect(find.text('널널'), findsOneWidget);
    expect(find.text('여행 시작하기'), findsOneWidget);

    await tester.tap(find.text('여행 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('카카오 로그인'), findsOneWidget);
    expect(find.text('네이버 로그인'), findsOneWidget);

    // 카카오 로그인은 이제 kakao_flutter_sdk_user로 실제 플랫폼 채널을 호출하므로
    // 위젯 테스트 환경(채널 미구현)에서는 탭해도 넘어가지 않는다. 네이버는 아직
    // SDK 연동 전 mock 동작이라 화면 전환 검증에는 네이버 버튼을 사용한다.
    await tester.tap(find.text('네이버 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('안녕하세요, 한적한 나그네님\n오늘은 어떤 여행지를 찾으시나요?'), findsOneWidget);

    await tester.tap(find.text('원주 간현관광지 이번 주말에 붐빌까?'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(find.text('오크밸리 빌리지센터'), findsOneWidget);

    // 장소 상세 화면의 이미지 영역(SkeletonBox)은 계속 반복 재생되는
    // AnimationController를 쓰기 때문에 pumpAndSettle이 끝나지 않는다.
    // 화면 전환에 필요한 프레임만 명시적으로 pump한다.
    await tester.tap(find.text('오크밸리 빌리지센터'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('장소 정보'), findsOneWidget);
    expect(find.text('강원특별자치도 원주시 지정면 오크밸리2길 66'), findsOneWidget);
    expect(find.text('033-730-3500'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('지난 대화'));
    await tester.pumpAndSettle();

    expect(find.text('최근'), findsOneWidget);
    expect(find.text('간현관광지 대신 원주 한적 코스'), findsOneWidget);

    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    expect(find.text('내 정보'), findsOneWidget);
    expect(find.text('한적한 나그네'), findsOneWidget);
    expect(find.text('네이버 계정'), findsOneWidget);
    expect(find.text('글자 크기'), findsOneWidget);
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('언어'), findsOneWidget);
    expect(find.text('시스템 언어'), findsOneWidget);

    // "언어" 섹션이 추가되며 하단 항목이 초기 뷰포트 밖으로 밀려났으므로
    // 스크롤해서 화면에 노출시킨 뒤 검증한다.
    await tester.dragUntilVisible(
      find.text('1.0.0 (1)'),
      find.byType(Scrollable),
      const Offset(0, -300),
    );
    expect(find.text('1.0.0 (1)'), findsOneWidget);
  });
}
