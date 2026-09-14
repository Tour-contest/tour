///
/// 한국어/영어 두 버전을 갖고 있으며, 화면 쪽에서 `Localizations.localeOf(context)
/// .languageCode`를 넘겨 고른다(`languageCode`가 `en`이 아니면 한국어). 이 파일은
/// 순수 Dart 라이브러리로 Flutter에 의존하지 않기 위해 `Locale` 대신 문자열
/// 코드를 받는다.
library;

enum Level { quiet, normal, busy }

Level levelForScore(int score) {
  if (score >= 60) return Level.busy;
  if (score >= 40) return Level.normal;
  return Level.quiet;
}

class PlaceRecommendation {
  const PlaceRecommendation({
    required this.name,
    required this.description,
    required this.congestionPercent,
    required this.location,
    required this.address,
    required this.phone,
    required this.introduction,
    this.category,
    this.imageUrl,
  });

  final String name;
  final String description;
  final int congestionPercent;

  Level get level => levelForScore(congestionPercent);

  final String? category;

  /// 상세 화면 이미지 영역용 네트워크 이미지 URL. 실제 이미지 소스 연동 전 단계라
  /// 아직 값이 없고(null), 로딩 전/실패 시 [SkeletonBox]로 대체된다.
  final String? imageUrl;

  /// 상세 화면용 짧은 위치 표기 (예: "충남 논산시 강경읍").
  final String location;

  /// 상세 화면용 전체 주소. 실제 내비게이션/지도 연동 시 그대로 쓰일 값이라
  /// 언어와 무관하게 한국 도로명주소를 유지한다(영어 버전에서도 번역하지 않음).
  final String address;

  /// 상세 화면용 전화번호.
  final String phone;

  /// 상세 화면용 장소 소개 문단.
  final String introduction;
}

class DailyScore {
  const DailyScore(
      {required this.date, required this.weekdayLabel, required this.score});

  final String date;
  final String weekdayLabel;
  final int score;

  Level get level => levelForScore(score);
}

class Forecast {
  const Forecast(
      {required this.spot, required this.days, required this.horizonDays});

  final PlaceRecommendation spot;
  final List<DailyScore> days;
  final int horizonDays;

  DailyScore get peak => days.reduce((a, b) => a.score >= b.score ? a : b);
}

class RegionStatus {
  const RegionStatus({
    required this.region,
    required this.counts,
    required this.popular,
    required this.quiet,
  });

  final String region;
  final Map<Level, int> counts;
  final List<PlaceRecommendation> popular;
  final List<PlaceRecommendation> quiet;
}

/// AI 응답을 구성하는 순서 있는 블록.
sealed class AiBlock {
  const AiBlock();
}

class TextBlock extends AiBlock {
  const TextBlock(this.text);
  final String text;
}

class ForecastBlock extends AiBlock {
  const ForecastBlock(this.forecast);
  final Forecast forecast;
}

class RegionBlock extends AiBlock {
  const RegionBlock(this.status);
  final RegionStatus status;
}

class NoDataBlock extends AiBlock {
  const NoDataBlock({required this.spotName, required this.actions});
  final String spotName;
  final List<String> actions;
}

/// 실제 백엔드 `ChatCardEvent`(`docs/API_SPEC.md`의 `card` 이벤트)를 그대로 담아두는
/// 블록. 카드 종류마다 스키마가 달라 파싱은 렌더링 시점(`widgets/nullnull/chat_card_view.dart`)에
/// `type`을 보고 한다 — 위의 `ForecastBlock` 등은 `MockChatApi`의 캔드 데이터 전용이고,
/// 이 블록이 실 서버 카드용이다.
class ChatCardBlock extends AiBlock {
  const ChatCardBlock({required this.type, required this.payload});
  final String type;
  final Map<String, dynamic> payload;
}

class AiTurn {
  const AiTurn(this.blocks);
  final List<AiBlock> blocks;
}

class DemoScript {
  DemoScript._();

  static bool _isEnglish(String languageCode) => languageCode == 'en';

  static const _ganhyeonKo = PlaceRecommendation(
    name: '간현관광지',
    description: '강원 원주 · 섬강을 따라 이어지는 대표 관광지',
    congestionPercent: 76,
    location: '강원 원주시 지정면',
    address: '강원특별자치도 원주시 지정면 소금산길 26',
    phone: '033-737-4995',
    introduction: '섬강을 따라 소금산 출렁다리와 산책로가 이어지는 원주의 대표 관광지예요. '
        '주말에는 전국 각지에서 인파가 몰려 매표소부터 줄이 길게 늘어서곤 해요.',
    category: '복합관광시설',
  );

  static const _forecastKo = Forecast(
    spot: _ganhyeonKo,
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

  static const _regionStatusKo = RegionStatus(
    region: '원주시',
    counts: {Level.quiet: 11, Level.normal: 7, Level.busy: 3},
    popular: [
      PlaceRecommendation(
        name: '간현관광지',
        description: '섬강을 따라 이어지는 대표 관광지',
        congestionPercent: 76,
        location: '강원 원주시 지정면',
        address: '강원특별자치도 원주시 지정면 소금산길 26',
        phone: '033-737-4995',
        introduction: '섬강을 따라 소금산 출렁다리와 산책로가 이어지는 원주의 대표 관광지예요.',
        category: '복합관광시설',
      ),
      PlaceRecommendation(
        name: '뮤지엄산',
        description: '안도 다다오가 설계한 미술관',
        congestionPercent: 58,
        location: '강원 원주시 지정면',
        address: '강원특별자치도 원주시 지정면 오크밸리2길 260',
        phone: '033-730-9000',
        introduction: '건축가 안도 다다오가 설계한 미술관으로, 자작나무길과 워터가든이 유명해요.',
        category: '문화시설',
      ),
    ],
    quiet: [
      PlaceRecommendation(
        name: '오크밸리 빌리지센터',
        description: '리조트 안 산책로가 있는 복합관광시설',
        congestionPercent: 27,
        location: '강원 원주시 지정면',
        address: '강원특별자치도 원주시 지정면 오크밸리2길 66',
        phone: '033-730-3500',
        introduction: '골프장과 함께 조성된 리조트 단지 안 복합관광시설이에요.',
        category: '복합관광시설',
      ),
      PlaceRecommendation(
        name: '소금산그랜드밸리',
        description: '협곡을 가로지르는 스카이타워 전망대',
        congestionPercent: 33,
        location: '강원 원주시 지정면',
        address: '강원특별자치도 원주시 지정면 소금산길 12',
        phone: '033-749-4930',
        introduction: '간현관광지 인근 협곡을 가로지르는 스카이타워 전망대예요.',
        category: '기타관광',
      ),
    ],
  );

  static const List<AiTurn> _turnsKo = [
    AiTurn([
      TextBlock('간현관광지는 이번 토요일(8월 23일)에 붐빌 것 같아요.'),
      TextBlock('집중률 76점으로 혼잡 구간이고, 일요일도 68점이라 주말 내내 붐빌 전망이에요.'),
      ForecastBlock(_forecastKo),
    ]),
    AiTurn([
      TextBlock('원주시의 오늘 현황이에요.'),
      RegionBlock(_regionStatusKo),
    ]),
    AiTurn([
      TextBlock('뮤지엄산은 아직 집중률 데이터가 제공되지 않아요.'),
      NoDataBlock(
        spotName: '뮤지엄산',
        actions: ['원주시 전체 현황 보기', '함께 찾는 곳 혼잡도 보기'],
      ),
    ]),
  ];

  static const _closingKo = AiTurn([
    TextBlock('데모는 여기까지예요. 왼쪽 위 ☰로 새 대화를 시작해보세요.'),
  ]);

  static const _ganhyeonEn = PlaceRecommendation(
    name: 'Ganhyeon Tourist Site',
    description: 'Wonju, Gangwon · A landmark site strung along the Seomgang',
    congestionPercent: 76,
    location: 'Jijeong-myeon, Wonju, Gangwon',
    address: '강원특별자치도 원주시 지정면 소금산길 26',
    phone: '033-737-4995',
    introduction:
        "Wonju's signature attraction, with the Sogeumsan suspension bridge "
        'and walking trails following the Seomgang river. Weekend crowds '
        'come from all over the country, and the ticket line can get long.',
    category: 'Mixed-use attraction',
  );

  static const _forecastEn = Forecast(
    spot: _ganhyeonEn,
    horizonDays: 7,
    days: [
      DailyScore(date: '08-18', weekdayLabel: 'Mon', score: 22),
      DailyScore(date: '08-19', weekdayLabel: 'Tue', score: 19),
      DailyScore(date: '08-20', weekdayLabel: 'Wed', score: 24),
      DailyScore(date: '08-21', weekdayLabel: 'Thu', score: 31),
      DailyScore(date: '08-22', weekdayLabel: 'Fri', score: 45),
      DailyScore(date: '08-23', weekdayLabel: 'Sat', score: 76),
      DailyScore(date: '08-24', weekdayLabel: 'Sun', score: 68),
    ],
  );

  static const _regionStatusEn = RegionStatus(
    region: 'Wonju',
    counts: {Level.quiet: 11, Level.normal: 7, Level.busy: 3},
    popular: [
      PlaceRecommendation(
        name: 'Ganhyeon Tourist Site',
        description: 'A landmark site along the Seomgang river',
        congestionPercent: 76,
        location: 'Jijeong-myeon, Wonju, Gangwon',
        address: '강원특별자치도 원주시 지정면 소금산길 26',
        phone: '033-737-4995',
        introduction:
            "Wonju's signature attraction, with the Sogeumsan suspension "
            'bridge and walking trails along the Seomgang.',
        category: 'Mixed-use attraction',
      ),
      PlaceRecommendation(
        name: 'Museum SAN',
        description: 'An art museum designed by Tadao Ando',
        congestionPercent: 58,
        location: 'Jijeong-myeon, Wonju, Gangwon',
        address: '강원특별자치도 원주시 지정면 오크밸리2길 260',
        phone: '033-730-9000',
        introduction:
            'An art museum designed by architect Tadao Ando, known for its '
            'birch-tree path and water garden.',
        category: 'Cultural facility',
      ),
    ],
    quiet: [
      PlaceRecommendation(
        name: 'Oakvalley Village Center',
        description: 'A resort attraction with quiet walking paths',
        congestionPercent: 27,
        location: 'Jijeong-myeon, Wonju, Gangwon',
        address: '강원특별자치도 원주시 지정면 오크밸리2길 66',
        phone: '033-730-3500',
        introduction: 'A mixed-use attraction inside a golf resort complex.',
        category: 'Mixed-use attraction',
      ),
      PlaceRecommendation(
        name: 'Sogeumsan Grand Valley',
        description: 'A sky tower observatory over the gorge',
        congestionPercent: 33,
        location: 'Jijeong-myeon, Wonju, Gangwon',
        address: '강원특별자치도 원주시 지정면 소금산길 12',
        phone: '033-749-4930',
        introduction: 'A sky tower observatory over the gorge near Ganhyeon.',
        category: 'Other attraction',
      ),
    ],
  );

  static const List<AiTurn> _turnsEn = [
    AiTurn([
      TextBlock(
          'Ganhyeon Tourist Site looks like it will be busy this Saturday '
          '(Aug 23).'),
      TextBlock('The congestion score is 76 — the busy range — and Sunday is '
          'at 68, so expect crowds all weekend.'),
      ForecastBlock(_forecastEn),
    ]),
    AiTurn([
      TextBlock("Here's today's overall status for Wonju."),
      RegionBlock(_regionStatusEn),
    ]),
    AiTurn([
      TextBlock("Museum SAN doesn't have congestion data yet."),
      NoDataBlock(
        spotName: 'Museum SAN',
        actions: [
          "See Wonju's overall status",
          'See congestion for nearby attractions',
        ],
      ),
    ]),
  ];

  static const _closingEn = AiTurn([
    TextBlock("That's the end of the demo. Tap ☰ in the top-left to start "
        'a new chat.'),
  ]);

  static AiTurn turnFor(int scriptIndex, [String languageCode = 'ko']) {
    final turns = _isEnglish(languageCode) ? _turnsEn : _turnsKo;
    if (scriptIndex < turns.length) return turns[scriptIndex];
    return _isEnglish(languageCode) ? _closingEn : _closingKo;
  }
}

class HistoryEntry {
  const HistoryEntry(
      {required this.title, required this.date, required this.preview});

  final String title;
  final String date;
  final String preview;
}

List<HistoryEntry> historyEntriesFor(String languageCode) =>
    languageCode == 'en' ? _historyEntriesEn : _historyEntriesKo;

const List<HistoryEntry> _historyEntriesKo = [
  HistoryEntry(
    title: '간현관광지 대신 원주 한적 코스',
    date: '08.16',
    preview: '집중률 76점인 간현관광지 대신 오크밸리 빌리지센터를 추천해드렸어요. 이동도 편한 '
        '원주 안에서 한적하게 즐기실 수 있어요.',
  ),
  HistoryEntry(
    title: '원주시 전체 현황 체크',
    date: '08.14',
    preview: '한적 11 · 보통 7 · 혼잡 3곳. 오후 2시 이후 혼잡도가 급격히 오릅니다.',
  ),
  HistoryEntry(
    title: '뮤지엄산 혼잡도 문의',
    date: '08.11',
    preview: '아직 집중률 데이터가 없어 원주시 전체 현황으로 대신 안내해드렸어요.',
  ),
  HistoryEntry(
    title: '소금산출렁다리 다녀오는 길',
    date: '08.05',
    preview: '이른 아침엔 한적했어요. 다음엔 해 질 녘에 가보세요.',
  ),
];

const List<HistoryEntry> _historyEntriesEn = [
  HistoryEntry(
    title: 'A quieter Wonju course instead of Ganhyeon',
    date: 'Aug 16',
    preview: 'Recommended Oakvalley Village Center instead of Ganhyeon (score '
        "76). Still easy to reach within Wonju's borders.",
  ),
  HistoryEntry(
    title: "Checking Wonju's overall status",
    date: 'Aug 14',
    preview: 'Quiet 11 · Normal 7 · Busy 3. Congestion rises sharply after '
        '2pm.',
  ),
  HistoryEntry(
    title: 'Asking about congestion at Museum SAN',
    date: 'Aug 11',
    preview: "No congestion data yet, so I showed Wonju's overall status "
        'instead.',
  ),
  HistoryEntry(
    title: 'On the way back from the suspension bridge',
    date: 'Aug 5',
    preview: 'Quiet in the early morning. Try visiting at sunset next time.',
  ),
];
