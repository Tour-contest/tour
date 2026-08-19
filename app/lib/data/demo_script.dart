/// 데모 대화 시나리오. docs/DESIGN.md "데모 대화 시나리오(canned script)" 참고.
library;

class PlaceRecommendation {
  const PlaceRecommendation({
    required this.name,
    required this.description,
    required this.congestionPercent,
    required this.location,
    required this.address,
    required this.phone,
    required this.introduction,
    this.imageUrl,
  });

  final String name;
  final String description;
  final int congestionPercent;

  /// 상세 화면 이미지 영역용 네트워크 이미지 URL. 실제 이미지 소스 연동 전 단계라
  /// 아직 값이 없고(null), 로딩 전/실패 시 [SkeletonBox]로 대체된다.
  final String? imageUrl;

  /// 상세 화면용 짧은 위치 표기 (예: "충남 논산시 강경읍").
  final String location;

  /// 상세 화면용 전체 주소.
  final String address;

  /// 상세 화면용 전화번호.
  final String phone;

  /// 상세 화면용 장소 소개 문단.
  final String introduction;
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
          location: '충남 논산시 강경읍',
          address: '충청남도 논산시 강경읍 계백로 361번길 11',
          phone: '041-746-8431',
          introduction: '1900년대 초 개항장으로 번성했던 강경의 옛 거리를 그대로 걷는 '
              '근대문화거리예요. 옛 한일은행 건물과 개항기 상점들이 남아 있어 사진 찍기 좋고, '
              '평일 오전에는 관광객이 거의 없어 한적하게 둘러볼 수 있어요.',
        ),
        PlaceRecommendation(
          name: '삼례문화예술촌',
          description: '전북 완주 · 옛 양곡창고를 개조한 조용한 예술공간',
          congestionPercent: 18,
          location: '전북 완주군 삼례읍',
          address: '전라북도 완주군 삼례읍 삼례역로 81',
          phone: '063-291-6799',
          introduction: '1920년대 지어진 양곡창고를 개조한 복합 문화공간이에요. 옛 창고의 '
              '골조를 그대로 살린 전시관과 카페가 모여 있어, 넓은 마당을 천천히 걸으며 여유롭게 '
              '둘러보기 좋아요.',
        ),
        PlaceRecommendation(
          name: '아리랑문학마을',
          description: '전북 김제 · 지평선 아래 고즈넉한 문학 마을',
          congestionPercent: 9,
          location: '전북 김제시 죽산면',
          address: '전라북도 김제시 죽산면 화초로 200',
          phone: '063-540-4064',
          introduction: '조정래 소설 「아리랑」의 배경이 된 김제 죽산면 일대를 재현한 문학 '
              '테마 마을이에요. 지평선이 끝없이 펼쳐지는 들녘과 옛 정미소, 일제강점기 가옥이 '
              '남아 있어 고즈넉한 산책을 즐기기 좋아요.',
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
