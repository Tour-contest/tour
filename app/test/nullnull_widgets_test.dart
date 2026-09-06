import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/chat_screen.dart';
import 'package:nullnull/screens/login_screen.dart';
import 'package:nullnull/theme/app_theme.dart';
import 'package:nullnull/widgets/app_drawer.dart';
import 'package:nullnull/widgets/nullnull/alternative_card.dart';
import 'package:nullnull/widgets/nullnull/congestion_badge.dart';
import 'package:nullnull/widgets/nullnull/forecast_card.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';
import 'package:nullnull/widgets/nullnull/no_data_card.dart';
import 'package:nullnull/widgets/nullnull/region_card.dart';

Widget _harness(Widget child, {double width = 390, double height = 844}) {
  return MaterialApp(
    theme: AppTheme.theme,
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Scaffold(
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

Widget _screenHarness(Widget screen,
    {double width = 390, double height = 844}) {
  return MaterialApp(
    theme: AppTheme.theme,
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: screen,
    ),
  );
}

const _forecast = Forecast(
  spot: PlaceRecommendation(
    name: '간현관광지',
    description: '강원 원주 · 섬강을 따라 이어지는 대표 관광지',
    congestionPercent: 76,
    location: '강원 원주시 지정면',
    address: '강원특별자치도 원주시 지정면 소금산길 26',
    phone: '033-737-4995',
    introduction: '테스트용 소개.',
  ),
  horizonDays: 7,
  days: [
    DailyScore(date: '08-18', weekdayLabel: '월', score: 22),
    DailyScore(date: '08-19', weekdayLabel: '화', score: 19),
    DailyScore(date: '08-20', weekdayLabel: '수', score: 24),
    DailyScore(date: '08-21', weekdayLabel: '목', score: 31),
    DailyScore(date: '08-22', weekdayLabel: '금', score: 45),
    DailyScore(date: '08-23', weekdayLabel: '토', score: 76),
    DailyScore(date: '08-24', weekdayLabel: '일', score: 68),
  ],
);

const _alternatives = [
  Alternative(
    rank: 1,
    spot: PlaceRecommendation(
      name: '오크밸리 빌리지센터',
      description: '테스트',
      congestionPercent: 27,
      location: '강원 원주시 지정면',
      address: '강원특별자치도 원주시 지정면 오크밸리2길 66',
      phone: '033-730-3500',
      introduction: '테스트용 소개.',
      category: '복합관광시설',
      travelMinutes: 12,
    ),
  ),
  Alternative(
    rank: 2,
    spot: PlaceRecommendation(
      name: '소금산그랜드밸리',
      description: '테스트',
      congestionPercent: 33,
      location: '강원 원주시 지정면',
      address: '강원특별자치도 원주시 지정면 소금산길 12',
      phone: '033-749-4930',
      introduction: '테스트용 소개.',
      category: '기타관광',
      travelMinutes: 8,
    ),
  ),
];

const _regionStatus = RegionStatus(
  region: '원주시',
  counts: {Level.quiet: 11, Level.normal: 7, Level.busy: 3},
  popular: [
    PlaceRecommendation(
      name: '간현관광지',
      description: '테스트',
      congestionPercent: 76,
      location: '강원 원주시 지정면',
      address: '강원특별자치도 원주시 지정면 소금산길 26',
      phone: '033-737-4995',
      introduction: '테스트용 소개.',
    ),
  ],
  quiet: [
    PlaceRecommendation(
      name: '오크밸리 빌리지센터',
      description: '테스트',
      congestionPercent: 27,
      location: '강원 원주시 지정면',
      address: '강원특별자치도 원주시 지정면 오크밸리2길 66',
      phone: '033-730-3500',
      introduction: '테스트용 소개.',
    ),
  ],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ForecastCard는 오버플로우 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(_harness(const ForecastCard(forecast: _forecast)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('간현관광지'), findsOneWidget);
  });

  testWidgets('AlternativesSection은 오버플로우 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(_harness(const AlternativesSection(
      items: _alternatives,
      excludedNote: '숙박·음식 연관지는 추천에서 제외했어요 (카페·리조트 등 7곳)',
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('오크밸리 빌리지센터'), findsOneWidget);
  });

  testWidgets('RegionCard는 오버플로우 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(_harness(const RegionCard(status: _regionStatus)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('원주시 여행지 추천'), findsOneWidget);
  });

  testWidgets('NoDataCard는 오버플로우 없이 렌더링되고 액션 탭이 전달된다', (tester) async {
    String? tapped;
    await tester.pumpWidget(_harness(NoDataCard(
      actions: const ['원주시 전체 현황 보기', '함께 찾는 곳 혼잡도 보기'],
      onActionTap: (label) => tapped = label,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('원주시 전체 현황 보기'));
    expect(tapped, '원주시 전체 현황 보기');
  });

  testWidgets('CongestionBadge/Mascot은 모든 레벨에서 예외 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(_harness(Wrap(
      children: [
        const Mascot(),
        for (final level in Level.values)
          CongestionBadge(level: level, score: 50),
      ],
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppDrawer는 좁은 화면에서도 오버플로우 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('open'),
            ),
          ),
        ),
        drawer: AppDrawer(onNewChat: () {}),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('널널'), findsOneWidget);
  });

  testWidgets('LoginScreen(S1)은 오버플로우 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(_screenHarness(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('카카오 로그인'), findsOneWidget);
    expect(find.text('네이버 로그인'), findsOneWidget);
  });

  testWidgets('ChatScreen 빈 상태(S2)는 오버플로우 없이 렌더링된다', (tester) async {
    await tester.pumpWidget(_screenHarness(const ChatScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
