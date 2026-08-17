/// 데모 대화 시나리오. docs/DESIGN.md "데모 대화 시나리오(canned script)" 참고.
library;

class PlaceRecommendation {
  const PlaceRecommendation({
    required this.name,
    required this.description,
    required this.congestionPercent,
  });

  final String name;
  final String description;
  final int congestionPercent;
}

class CourseStep {
  const CourseStep({required this.time, required this.title});

  final String time;
  final String title;
}

/// AI 응답을 구성하는 순서 있는 블록.
sealed class AiBlock {
  const AiBlock();
}

class TextBlock extends AiBlock {
  const TextBlock(this.text);
  final String text;
}

class PlaceListBlock extends AiBlock {
  const PlaceListBlock(this.items);
  final List<PlaceRecommendation> items;
}

class CourseListBlock extends AiBlock {
  const CourseListBlock(this.items);
  final List<CourseStep> items;
}

class AiTurn {
  const AiTurn(this.blocks);
  final List<AiBlock> blocks;
}

class DemoScript {
  DemoScript._();

  static const List<String> suggestedPrompts = [
    '이번 주말 전주 한옥마을 대신 갈 만한 곳',
    '지금 제주 애월 혼잡도 어때?',
    '당일치기로 조용한 바다 보고 오고 싶어',
  ];

  static const List<AiTurn> turns = [
    AiTurn([
      TextBlock('이번 주말 전주 한옥마을은 혼잡도가 평소보다 38% 높게 예보돼요. '
          '비슷한 정취의 한적한 대안지 세 곳을 준비했어요.'),
      PlaceListBlock([
        PlaceRecommendation(
          name: '강경 근대거리',
          description: '충남 논산 · 100년 전 거리를 그대로 걷는 근대문화거리',
          congestionPercent: 12,
        ),
        PlaceRecommendation(
          name: '삼례문화예술촌',
          description: '전북 완주 · 옛 양곡창고를 개조한 조용한 예술공간',
          congestionPercent: 18,
        ),
        PlaceRecommendation(
          name: '아리랑문학마을',
          description: '전북 김제 · 지평선 아래 고즈넉한 문학 마을',
          congestionPercent: 9,
        ),
      ]),
      TextBlock('마음에 드는 곳이 있으면 반나절 코스도 짜드릴게요.'),
    ]),
    AiTurn([
      TextBlock('강경 근대거리 반나절 코스예요. 이른 시간에 움직이면 더 한적하게 즐길 수 있어요.'),
      CourseListBlock([
        CourseStep(time: '10:00', title: '옛 한일은행'),
        CourseStep(time: '11:00', title: '골목 산책'),
        CourseStep(time: '12:30', title: '젓갈정식'),
        CourseStep(time: '14:00', title: '옥녀봉 전망'),
      ]),
      TextBlock('코스를 저장해드릴까요?'),
    ]),
    AiTurn([
      TextBlock('저장했어요. 출발 전날 혼잡도를 다시 확인해서 알려드릴게요.'),
    ]),
  ];

  static const AiTurn closing = AiTurn([
    TextBlock('데모는 여기까지예요. 왼쪽 위 ✎로 새 대화를 시작해보세요.'),
  ]);

  static AiTurn turnFor(int scriptIndex) {
    if (scriptIndex < turns.length) return turns[scriptIndex];
    return closing;
  }
}

class HistoryEntry {
  const HistoryEntry(
      {required this.title, required this.date, required this.preview});

  final String title;
  final String date;
  final String preview;
}

const List<HistoryEntry> historyEntries = [
  HistoryEntry(
    title: '강경 반나절, 전주 대신 한적하게',
    date: '08.16',
    preview: '혼잡도 12%인 강경 근대거리 코스예요. 옛 한일은행에서 시작해 골목을 걷고 '
        '젓갈정식을 먹은 뒤 옥녀봉에서 노을을 봐요.',
  ),
  HistoryEntry(
    title: '제주 애월 혼잡도 체크',
    date: '08.14',
    preview: '애월 해안도로는 오후 2시 이후 혼잡도가 급격히 오릅니다. 오전 방문을 추천해요.',
  ),
  HistoryEntry(
    title: '당일치기 조용한 바다 여행지 추천',
    date: '08.11',
    preview: '인파 적은 서해의 소도시 세 곳을 골라봤어요. 대천보다 한적한 곳으로요.',
  ),
  HistoryEntry(
    title: '아리랑문학마을 다녀오는 길',
    date: '08.05',
    preview: '지평선 아래 고즈넉한 마을이었어요. 다음엔 노을 시간에 가보세요.',
  ),
];
