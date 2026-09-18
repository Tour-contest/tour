import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/demo_script.dart' show Level;

/// `attraction_list` 카드(`docs/API_SPEC.md`의 `### chat`에서 확인된 스키마)의
/// `items` 항목과 동일한 모양. `attractions/search`·`/{content_id}` 등도 같은
/// 원자료(공공데이터 관광지 정보)를 쓸 가능성이 높아 필드명을 그대로 따랐다 —
/// 실제 응답으로 다른 점이 확인되면 이 `fromJson`만 갱신하면 된다.
class AttractionSummary {
  const AttractionSummary({
    required this.contentId,
    required this.title,
    this.contentTypeId,
    this.addr1,
    this.addr2,
    this.tel,
    this.image,
    this.mapX,
    this.mapY,
    this.tourCd,
    this.signguCd,
    this.signguNm,
  });

  factory AttractionSummary.fromJson(Map<String, dynamic> json) {
    return AttractionSummary(
      contentId: json['content_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      contentTypeId: json['content_type_id']?.toString(),
      addr1: json['addr1'] as String?,
      addr2: json['addr2'] as String?,
      tel: json['tel'] as String?,
      image: json['image'] as String?,
      mapX: (json['mapx'] as num?)?.toDouble(),
      mapY: (json['mapy'] as num?)?.toDouble(),
      tourCd: json['tour_cd'] as String?,
      signguCd: json['signgu_cd'] as String?,
      signguNm: json['signgu_nm'] as String?,
    );
  }

  final String contentId;
  final String title;
  final String? contentTypeId;
  final String? addr1;
  final String? addr2;
  final String? tel;
  final String? image;
  final double? mapX;
  final double? mapY;
  final String? tourCd;
  final String? signguCd;
  final String? signguNm;

  String get address =>
      addr2 != null && addr2!.isNotEmpty ? '$addr1 $addr2' : (addr1 ?? '');
}

/// `GET /api/v1/attractions/search`. [confident]가 `true`면 [items]가 단일
/// 확정 결과다(`docs/API_SPEC.md`) — 그래도 자동으로 첫 항목을 골라 쓰기보단
/// 호출부가 `confident` 값을 직접 확인하는 편이 안전하다(`confident:false`는
/// `resolve`의 `ambiguous`와 같은 선택 UI 분기 케이스).
class AttractionSearchResult {
  const AttractionSearchResult({required this.confident, required this.items});

  factory AttractionSearchResult.fromJson(Map<String, dynamic> json) {
    return AttractionSearchResult(
      confident: json['confident'] as bool? ?? false,
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionSummary.fromJson)
          .toList(),
    );
  }

  final bool confident;
  final List<AttractionSummary> items;
}

/// `attractions/{content_id}`의 "이용정보" 한 건(`data.info`는 이 형태의
/// 배열로 온다 — `{label, value}`, **실서버로 확인함**).
class AttractionInfoItem {
  const AttractionInfoItem({required this.label, required this.value});

  factory AttractionInfoItem.fromJson(Map<String, dynamic> json) {
    return AttractionInfoItem(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  final String label;
  final String value;
}

/// `GET /api/v1/attractions/{content_id}`. [source]는 공공데이터 출처
/// 표기 문구(예: "출처: ⓒ한국관광공사", **실서버로 확인함**).
class AttractionDetail {
  const AttractionDetail(
      {required this.summary,
      this.overview,
      this.info = const [],
      this.source});

  factory AttractionDetail.fromJson(Map<String, dynamic> json) {
    return AttractionDetail(
      summary: AttractionSummary.fromJson(json),
      overview: json['overview'] as String?,
      info: ((json['info'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionInfoItem.fromJson)
          .toList(),
      source: json['source'] as String?,
    );
  }

  final AttractionSummary summary;
  final String? overview;
  final List<AttractionInfoItem> info;
  final String? source;
}

/// `attractions/{content_id}/crowd`의 일자별 예측 혼잡도 한 건. **[실서버로
/// 확인함]** [weekday]는 서버가 이미 한글 요일 약자("월"/"화"/...)로 내려줘
/// 클라이언트에서 `DateTime.weekday`로 다시 계산할 필요가 없다. [rate]는 `%`
/// 기호 없는 숫자(집중률, 실제로는 소수라 배지 표시를 위해 반올림해 정수로
/// 보관)이고, [level]은 `혼잡`/`보통`/`한적` 세 값만 온다.
class AttractionCrowdDay {
  const AttractionCrowdDay({
    required this.date,
    required this.weekday,
    required this.rate,
    required this.level,
  });

  factory AttractionCrowdDay.fromJson(Map<String, dynamic> json) {
    return AttractionCrowdDay(
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      weekday: json['weekday'] as String? ?? '',
      rate: ((json['rate'] as num?) ?? 0).round(),
      level: levelForKoreanLabel(json['level'] as String?),
    );
  }

  final DateTime? date;
  final String weekday;
  final int rate;
  final Level level;
}

/// 기간 요약(**실서버로 확인함**) — 애초 가정했던 `average_rate`/`level`이
/// 아니라, 최고/최저 집중률과 그 날짜, 평균(`avg`)이다. `level`은 오지 않는다
/// (서버가 등급을 안 매겨주므로 클라이언트에서 임의 기준으로 나누지 않음).
class AttractionCrowdPeriodSummary {
  const AttractionCrowdPeriodSummary({
    this.peakDate,
    required this.peakRate,
    this.minDate,
    required this.minRate,
    required this.avg,
  });

  factory AttractionCrowdPeriodSummary.fromJson(Map<String, dynamic> json) {
    return AttractionCrowdPeriodSummary(
      peakDate: DateTime.tryParse(json['peak_date'] as String? ?? ''),
      peakRate: ((json['peak_rate'] as num?) ?? 0).round(),
      minDate: DateTime.tryParse(json['min_date'] as String? ?? ''),
      minRate: ((json['min_rate'] as num?) ?? 0).round(),
      avg: ((json['avg'] as num?) ?? 0).round(),
    );
  }

  final DateTime? peakDate;
  final int peakRate;
  final DateTime? minDate;
  final int minRate;
  final int avg;
}

/// **[실서버로 확인함]** 일자별 목록의 최상위 키가 애초 가정했던 `days`가
/// 아니라 `series`였다 — 이전 코드는 이 키 불일치 때문에 매번 빈 목록을
/// 반환하고 있었다. [matchedName]/[availableDays]/[signguNm]/[source]도
/// 함께 확인돼 추가했다(`content_id`/`match_method`/`match_confidence`/
/// `has_data`는 화면에 쓸 일이 없어 모델링하지 않음).
class AttractionCrowdForecast {
  const AttractionCrowdForecast({
    required this.days,
    this.summary,
    this.matchedName,
    this.availableDays,
    this.signguNm,
    this.source,
  });

  factory AttractionCrowdForecast.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>?;
    return AttractionCrowdForecast(
      days: ((json['series'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionCrowdDay.fromJson)
          .toList(),
      summary: summaryJson == null
          ? null
          : AttractionCrowdPeriodSummary.fromJson(summaryJson),
      matchedName: json['matched_name'] as String?,
      availableDays: (json['available_days'] as num?)?.toInt(),
      signguNm: json['signgu_nm'] as String?,
      source: json['source'] as String?,
    );
  }

  final List<AttractionCrowdDay> days;
  final AttractionCrowdPeriodSummary? summary;
  final String? matchedName;
  final int? availableDays;
  final String? signguNm;
  final String? source;
}

/// 대안지 원본 관광지 자신의 현재 혼잡도(비교 기준). `data.base`
/// (**실서버로 확인함**).
class AttractionAlternativeBase {
  const AttractionAlternativeBase({
    required this.name,
    required this.rate,
    required this.level,
  });

  factory AttractionAlternativeBase.fromJson(Map<String, dynamic> json) {
    return AttractionAlternativeBase(
      name: json['name'] as String? ?? '',
      rate: ((json['rate'] as num?) ?? 0).round(),
      level: levelForKoreanLabel(json['level'] as String?),
    );
  }

  final String name;
  final int rate;
  final Level level;
}

/// 대안지 추천 사유(**실서버로 확인함**) — `same_category`가 `true`일 때만
/// `similarity`(소개문 임베딩 유사도)가 오고, 아니면 `null`이다.
class AttractionAlternativeReason {
  const AttractionAlternativeReason({
    required this.lowerBy,
    required this.sameCategory,
    required this.distanceKm,
    this.similarity,
  });

  factory AttractionAlternativeReason.fromJson(Map<String, dynamic> json) {
    return AttractionAlternativeReason(
      lowerBy: ((json['lower_by'] as num?) ?? 0).toDouble(),
      sameCategory: json['same_category'] as bool? ?? false,
      distanceKm: ((json['distance_km'] as num?) ?? 0).toDouble(),
      similarity: (json['similarity'] as num?)?.toDouble(),
    );
  }

  final double lowerBy;
  final bool sameCategory;
  final double distanceKm;
  final double? similarity;
}

/// `attractions/{content_id}/alternatives`의 대안지 한 건. **[실서버로 확인함]**
/// `AttractionSummary`(`title`/`addr2`/`tel`/`mapx`/`mapy`/`tour_cd`/`signgu_cd`
/// 등)를 그대로 쓸 수 있을 거라 가정했으나, 실제로는 제목 필드명이 `title`이
/// 아니라 `name`이고 그 외 필드도 상당수 빠져 있어 별도 모델로 새로 뺐다.
/// [rate]/[level]은 그 대안지 자체의 혼잡도다. 목록 순서는 서버가 혼잡도
/// 우선으로 이미 정렬해 보내므로, 호출부는 유사도 등 다른 기준으로
/// **재정렬하면 안 된다**(`docs/API_SPEC.md`).
class AttractionAlternative {
  const AttractionAlternative({
    required this.contentId,
    required this.name,
    required this.rate,
    required this.level,
    this.date,
    this.image,
    this.addr1,
    this.reason,
  });

  factory AttractionAlternative.fromJson(Map<String, dynamic> json) {
    final reasonJson = json['reason'] as Map<String, dynamic>?;
    return AttractionAlternative(
      contentId: json['content_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      rate: ((json['rate'] as num?) ?? 0).round(),
      level: levelForKoreanLabel(json['level'] as String?),
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      image: json['image'] as String?,
      addr1: json['addr1'] as String?,
      reason: reasonJson == null
          ? null
          : AttractionAlternativeReason.fromJson(reasonJson),
    );
  }

  final String contentId;
  final String name;
  final int rate;
  final Level level;
  final DateTime? date;
  final String? image;
  final String? addr1;
  final AttractionAlternativeReason? reason;
}

/// `GET .../alternatives` 전체 응답(**실서버로 확인함**). [base]는 원본
/// 관광지 자신의 현재 혼잡도(비교 기준), [source]는 공공데이터 출처 표기
/// 문구다. `sort_basis`/`relaxed`/`candidate_source`는 서버 내부 로직
/// 설명용으로 보여 화면에 쓸 일이 없어 모델링하지 않았다.
class AttractionAlternativesResult {
  const AttractionAlternativesResult({
    this.base,
    required this.items,
    this.signguNm,
    this.source,
  });

  factory AttractionAlternativesResult.fromJson(Map<String, dynamic> json) {
    final baseJson = json['base'] as Map<String, dynamic>?;
    return AttractionAlternativesResult(
      base: baseJson == null
          ? null
          : AttractionAlternativeBase.fromJson(baseJson),
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionAlternative.fromJson)
          .toList(),
      signguNm: json['signgu_nm'] as String?,
      source: json['source'] as String?,
    );
  }

  final AttractionAlternativeBase? base;
  final List<AttractionAlternative> items;
  final String? signguNm;
  final String? source;
}

/// `attractions/{content_id}/interest`의 검색 관심도 요약 한 건.
/// **[실서버로 확인함]** 애초 가정했던 시계열 포인트(`period`/`ratio`) 배열이
/// 아니라, 최근 [weeks]주간의 방향성 요약(`trend`)과 증감률(`changePct`)
/// 하나였다 — 네이버 데이터랩을 그대로 프록시하는 게 아니라 서버가 이미
/// 요약해서 내려주는 형태. [trend]는 지금까지 `flat`만 확인됐고 `up`/`down`
/// 같은 다른 값도 있을 가능성이 높아 exhaustive enum 대신 원문 문자열로
/// 받아둔다(알 수 없는 값이 와도 화면이 깨지지 않도록).
class AttractionInterestItem {
  const AttractionInterestItem({
    required this.name,
    required this.trend,
    required this.changePct,
    required this.weeks,
    required this.displayName,
  });

  factory AttractionInterestItem.fromJson(Map<String, dynamic> json) {
    return AttractionInterestItem(
      name: json['name'] as String? ?? '',
      trend: json['trend'] as String? ?? '',
      changePct: ((json['change_pct'] as num?) ?? 0).toDouble(),
      weeks: (json['weeks'] as num?)?.toInt() ?? 0,
      displayName: json['display_name'] as String? ?? '',
    );
  }

  final String name;
  final String trend;
  final double changePct;
  final int weeks;
  final String displayName;
}

class AttractionInterestTrend {
  const AttractionInterestTrend({required this.items});

  factory AttractionInterestTrend.fromJson(Map<String, dynamic> json) {
    return AttractionInterestTrend(
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionInterestItem.fromJson)
          .toList(),
    );
  }

  final List<AttractionInterestItem> items;
}

/// `attractions/{content_id}/images`의 서브 이미지 한 건. **[실서버로
/// 확인함]** `url`/`small`(썸네일)/`name`(캡션, 보통 관광지 이름과 동일)/
/// `copyright`(이미지별 저작권 표시, 예: "공공누리 제1유형 (출처표시)") 구조로
/// 온다 — `copyright`는 공공누리 라이선스 조건상 이미지별로 표기해야 할 수
/// 있어 버리지 않고 모델에 담아둔다(화면에 아직 노출은 안 함).
class AttractionImage {
  const AttractionImage({
    required this.url,
    this.small,
    this.name,
    this.copyright,
  });

  factory AttractionImage.fromJson(Map<String, dynamic> json) {
    return AttractionImage(
      url: json['url'] as String? ?? '',
      small: json['small'] as String?,
      name: json['name'] as String?,
      copyright: json['copyright'] as String?,
    );
  }

  final String url;
  final String? small;
  final String? name;
  final String? copyright;
}

/// `attractions/{content_id}/images`(캐러셀용 서브 이미지) 전체 응답.
class AttractionImages {
  const AttractionImages({required this.items, this.source});

  factory AttractionImages.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return AttractionImages(
      items: rawItems
          .map(_parseItem)
          .whereType<AttractionImage>()
          .where((image) => image.url.isNotEmpty)
          .toList(),
      source: json['source'] as String?,
    );
  }

  /// 다른 모델들처럼 nullable 캐스트로 방어적으로 파싱한다 — 항목이 문자열도
  /// `Map`도 아니면(예: `null`이 섞여 옴) 예전엔 `as Map<String, dynamic>` 강제
  /// 캐스트가 `TypeError`를 던졌는데, 이제는 그 항목만 조용히 건너뛴다.
  static AttractionImage? _parseItem(dynamic item) {
    if (item is String) return AttractionImage(url: item);
    if (item is Map<String, dynamic>) return AttractionImage.fromJson(item);
    return null;
  }

  final List<AttractionImage> items;
  final String? source;

  /// `_ImageCarousel`이 쓰는 URL만 뽑은 목록(화면 쪽 변경을 줄이기 위한
  /// 편의 getter).
  List<String> get imageUrls => items.map((image) => image.url).toList();
}

/// `attractions/{content_id}/pet`(반려동물 동반 정보). **[실서버로 확인함]**
/// 값이 있는 예시로 [items]도 `info`와 완전히 같은 `{label, value}` 배열
/// 구조임이 확인됐다(예: "동반 구분"/"전구역 동반가능") — `AttractionInfoItem`을
/// 그대로 재사용한다.
class AttractionPetInfo {
  const AttractionPetInfo({
    required this.status,
    required this.items,
    this.source,
  });

  factory AttractionPetInfo.fromJson(Map<String, dynamic> json) {
    return AttractionPetInfo(
      status: json['status'] as String? ?? '',
      items: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionInfoItem.fromJson)
          .toList(),
      source: json['source'] as String?,
    );
  }

  final String status;
  final List<AttractionInfoItem> items;
  final String? source;

  bool get hasData => status != 'no_data' && items.isNotEmpty;
}

/// `attractions/{content_id}/similar`(소개문 임베딩 코사인 유사도) 한 건.
/// **[실서버로 확인함]** `AttractionSummary` 재사용 가정(`content_id`/`title`)이
/// 그대로 맞았다 — `alternatives`(제목 필드가 `title`이 아니라 `name`)와 달리
/// 이 엔드포인트는 애초 예상대로 옴. `similarity`도 0~1 범위 소수로 확인돼
/// 화면의 `(similarity * 100).round()` 퍼센트 변환이 그대로 유효하다.
class SimilarAttraction {
  const SimilarAttraction({required this.summary, required this.similarity});

  factory SimilarAttraction.fromJson(Map<String, dynamic> json) {
    return SimilarAttraction(
      summary: AttractionSummary.fromJson(json),
      similarity: ((json['similarity'] as num?) ?? 0).toDouble(),
    );
  }

  final AttractionSummary summary;
  final double similarity;
}

/// `GET /api/v1/me/recent-attractions`의 한 건. `viewed_at` 필드명은 가정이다.
class RecentAttraction {
  const RecentAttraction({required this.summary, this.viewedAt});

  factory RecentAttraction.fromJson(Map<String, dynamic> json) {
    return RecentAttraction(
      summary: AttractionSummary.fromJson(json),
      viewedAt:
          DateTime.tryParse(json['viewed_at'] as String? ?? '')?.toLocal(),
    );
  }

  final AttractionSummary summary;
  final DateTime? viewedAt;
}

/// `docs/API_SPEC.md`의 `혼잡`/`보통`/`한적` 세 값만 오는 등급 문자열을 [Level]로
/// 매핑한다(`areas_api.dart`의 동일한 매핑과 같은 규칙, 파일마다 작은 헬퍼를
/// 따로 두는 기존 컨벤션을 따름 — `chat_card_view.dart`의 `CrowdCardData._levelFor` 참고).
Level levelForKoreanLabel(String? koreanLabel) => switch (koreanLabel) {
      '혼잡' => Level.busy,
      '한적' => Level.quiet,
      _ => Level.normal,
    };

/// [AttractionsApi] 호출이 실패했을 때 던지는 예외(`AreasApiException`과 동일한
/// 모양). [statusCode]로 상세 조회의 404/503처럼 하위 조회를 계속할지 판단한다
/// (`docs/API_SPEC.md`의 "구현 주의": 404/503이면 나머지 상세 화면 하위 조회를
/// 호출하지 않는다).
class AttractionsApiException implements Exception {
  AttractionsApiException(
    this.message, {
    this.retriable = false,
    this.statusCode,
  });
  final String message;
  final bool retriable;
  final int? statusCode;

  bool get isNotFoundOrUnavailable => statusCode == 404 || statusCode == 503;

  @override
  String toString() => message;
}

/// `docs/API_SPEC.md`의 `### attractions` 절 API. `ChatApi`와 동일한 봉투
/// 언래핑 패턴을 쓴다.
abstract class AttractionsApi {
  /// `GET /api/v1/attractions/search?keyword=&signgu_cd=`.
  Future<AttractionSearchResult> search({
    required String keyword,
    String? signguCd,
  });

  /// `GET /api/v1/attractions/{content_id}`. 성공하면 서버가 "최근 본 관광지"에
  /// 자동으로 기록한다. 실패(404/503)면 [AttractionsApiException.isNotFoundOrUnavailable]로
  /// 판단해 호출부가 나머지 하위 조회(crowd/images/pet 등)를 생략해야 한다.
  Future<AttractionDetail> fetchDetail({required String contentId});

  /// `GET /api/v1/attractions/{content_id}/crowd?days=&date_from=`.
  Future<AttractionCrowdForecast> fetchCrowd({
    required String contentId,
    int? days,
    DateTime? dateFrom,
  });

  /// `GET /api/v1/attractions/{content_id}/alternatives?date=&limit=`.
  /// `items` 순서를 그대로 유지해야 한다(재정렬 금지).
  Future<AttractionAlternativesResult> fetchAlternatives({
    required String contentId,
    DateTime? date,
    int? limit,
  });

  /// `GET /api/v1/attractions/{content_id}/interest?weeks=`.
  Future<AttractionInterestTrend> fetchInterest({
    required String contentId,
    int? weeks,
  });

  /// `GET /api/v1/attractions/{content_id}/images`.
  Future<AttractionImages> fetchImages({required String contentId});

  /// `GET /api/v1/attractions/{content_id}/pet`.
  Future<AttractionPetInfo> fetchPetInfo({required String contentId});

  /// `GET /api/v1/attractions/{content_id}/similar?limit=`(DB 계산, 상류 호출 없음).
  Future<List<SimilarAttraction>> fetchSimilar({
    required String contentId,
    int? limit,
  });

  /// `GET /api/v1/me/recent-attractions`.
  Future<List<RecentAttraction>> fetchRecentAttractions();

  /// `DELETE /api/v1/me/recent-attractions`(전체 삭제, 개별 삭제 없음).
  Future<void> clearRecentAttractions();
}

/// [AttractionsApi] 호출/응답을 [AppLog.logger]로 남기는 데코레이터(`LoggingChatApi`와
/// 동일한 패턴).
class LoggingAttractionsApi implements AttractionsApi {
  LoggingAttractionsApi(this._inner);

  final AttractionsApi _inner;

  @override
  Future<AttractionSearchResult> search({
    required String keyword,
    String? signguCd,
  }) async {
    AppLog.logger.i(
        '[AttractionsApi] search → keyword: "$keyword", signguCd: $signguCd');
    try {
      final result = await _inner.search(keyword: keyword, signguCd: signguCd);
      AppLog.logger.d(
          '[AttractionsApi] ← confident: ${result.confident}, items: ${result.items.length}건');
      return result;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[AttractionsApi] search 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AttractionDetail> fetchDetail({required String contentId}) async {
    AppLog.logger.i('[AttractionsApi] fetchDetail → contentId: $contentId');
    try {
      final detail = await _inner.fetchDetail(contentId: contentId);
      AppLog.logger.d('[AttractionsApi] ← ${detail.summary.title}');
      return detail;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchDetail 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AttractionCrowdForecast> fetchCrowd({
    required String contentId,
    int? days,
    DateTime? dateFrom,
  }) async {
    AppLog.logger.i(
        '[AttractionsApi] fetchCrowd → contentId: $contentId, days: $days, dateFrom: $dateFrom');
    try {
      final forecast = await _inner.fetchCrowd(
          contentId: contentId, days: days, dateFrom: dateFrom);
      AppLog.logger.d('[AttractionsApi] ← ${forecast.days.length}일');
      return forecast;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchCrowd 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AttractionAlternativesResult> fetchAlternatives({
    required String contentId,
    DateTime? date,
    int? limit,
  }) async {
    AppLog.logger.i(
        '[AttractionsApi] fetchAlternatives → contentId: $contentId, date: $date, limit: $limit');
    try {
      final result = await _inner.fetchAlternatives(
          contentId: contentId, date: date, limit: limit);
      AppLog.logger.d('[AttractionsApi] ← ${result.items.length}건');
      return result;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchAlternatives 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AttractionInterestTrend> fetchInterest({
    required String contentId,
    int? weeks,
  }) async {
    AppLog.logger.i(
        '[AttractionsApi] fetchInterest → contentId: $contentId, weeks: $weeks');
    try {
      final trend =
          await _inner.fetchInterest(contentId: contentId, weeks: weeks);
      AppLog.logger.d('[AttractionsApi] ← ${trend.items.length}건');
      return trend;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchInterest 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AttractionImages> fetchImages({required String contentId}) async {
    AppLog.logger.i('[AttractionsApi] fetchImages → contentId: $contentId');
    try {
      final images = await _inner.fetchImages(contentId: contentId);
      AppLog.logger.d('[AttractionsApi] ← ${images.imageUrls.length}건');
      return images;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchImages 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AttractionPetInfo> fetchPetInfo({required String contentId}) async {
    AppLog.logger.i('[AttractionsApi] fetchPetInfo → contentId: $contentId');
    try {
      final info = await _inner.fetchPetInfo(contentId: contentId);
      AppLog.logger.d('[AttractionsApi] ← status: ${info.status}');
      return info;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchPetInfo 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<SimilarAttraction>> fetchSimilar({
    required String contentId,
    int? limit,
  }) async {
    AppLog.logger.i(
        '[AttractionsApi] fetchSimilar → contentId: $contentId, limit: $limit');
    try {
      final similar =
          await _inner.fetchSimilar(contentId: contentId, limit: limit);
      AppLog.logger.d('[AttractionsApi] ← ${similar.length}건');
      return similar;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchSimilar 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<RecentAttraction>> fetchRecentAttractions() async {
    AppLog.logger.i('[AttractionsApi] fetchRecentAttractions');
    try {
      final recents = await _inner.fetchRecentAttractions();
      AppLog.logger.d('[AttractionsApi] ← ${recents.length}건');
      return recents;
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] fetchRecentAttractions 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> clearRecentAttractions() async {
    AppLog.logger.i('[AttractionsApi] clearRecentAttractions');
    try {
      await _inner.clearRecentAttractions();
      AppLog.logger.d('[AttractionsApi] ← clearRecentAttractions 완료');
    } catch (e, stackTrace) {
      AppLog.logger.e('[AttractionsApi] clearRecentAttractions 실패',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// [AppConfig]의 `attraction*Endpoint`/`recentAttractionsEndpoint`로 실제
/// 요청을 보내는 구현.
class DioAttractionsApi implements AttractionsApi {
  DioAttractionsApi(this._dio);

  final Dio _dio;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  Future<AttractionSearchResult> search({
    required String keyword,
    String? signguCd,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.attractionsSearchEndpoint,
      queryParameters: {
        'keyword': keyword,
        if (signguCd != null) 'signgu_cd': signguCd,
      },
    );
    final data = _unwrap(response, errorMessage: '관광지를 찾지 못했어요.');
    return AttractionSearchResult.fromJson(data);
  }

  @override
  Future<AttractionDetail> fetchDetail({required String contentId}) async {
    final response = await _get<Map<String, dynamic>>(
        AppConfig.attractionEndpoint(contentId));
    final data = _unwrap(response, errorMessage: '관광지 정보를 불러오지 못했어요.');
    return AttractionDetail.fromJson(data);
  }

  @override
  Future<AttractionCrowdForecast> fetchCrowd({
    required String contentId,
    int? days,
    DateTime? dateFrom,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.attractionCrowdEndpoint(contentId),
      queryParameters: {
        if (days != null) 'days': days,
        if (dateFrom != null) 'date_from': _dateFormat.format(dateFrom),
      },
    );
    final data = _unwrap(response, errorMessage: '혼잡도 예보를 불러오지 못했어요.');
    return AttractionCrowdForecast.fromJson(data);
  }

  @override
  Future<AttractionAlternativesResult> fetchAlternatives({
    required String contentId,
    DateTime? date,
    int? limit,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.attractionAlternativesEndpoint(contentId),
      queryParameters: {
        if (date != null) 'date': _dateFormat.format(date),
        if (limit != null) 'limit': limit,
      },
    );
    final data = _unwrap(response, errorMessage: '대안 여행지를 불러오지 못했어요.');
    // `items` 순서는 서버가 이미 혼잡도 우선으로 정렬해 보내므로 여기서
    // 재정렬하지 않는다.
    return AttractionAlternativesResult.fromJson(data);
  }

  @override
  Future<AttractionInterestTrend> fetchInterest({
    required String contentId,
    int? weeks,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.attractionInterestEndpoint(contentId),
      queryParameters: weeks == null ? null : {'weeks': weeks},
    );
    final data = _unwrap(response, errorMessage: '검색 관심도를 불러오지 못했어요.');
    return AttractionInterestTrend.fromJson(data);
  }

  @override
  Future<AttractionImages> fetchImages({required String contentId}) async {
    final response = await _get<Map<String, dynamic>>(
        AppConfig.attractionImagesEndpoint(contentId));
    final data = _unwrap(response, errorMessage: '이미지를 불러오지 못했어요.');
    return AttractionImages.fromJson(data);
  }

  @override
  Future<AttractionPetInfo> fetchPetInfo({required String contentId}) async {
    final response = await _get<Map<String, dynamic>>(
        AppConfig.attractionPetEndpoint(contentId));
    final data = _unwrap(response, errorMessage: '반려동물 동반 정보를 불러오지 못했어요.');
    return AttractionPetInfo.fromJson(data);
  }

  @override
  Future<List<SimilarAttraction>> fetchSimilar({
    required String contentId,
    int? limit,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.attractionSimilarEndpoint(contentId),
      queryParameters: limit == null ? null : {'limit': limit},
    );
    final data = _unwrap(response, errorMessage: '비슷한 관광지를 불러오지 못했어요.');
    return ((data['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SimilarAttraction.fromJson)
        .toList();
  }

  @override
  Future<List<RecentAttraction>> fetchRecentAttractions() async {
    final response =
        await _get<Map<String, dynamic>>(AppConfig.recentAttractionsEndpoint);
    final data = _unwrap(response, errorMessage: '최근 본 관광지를 불러오지 못했어요.');
    return ((data['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(RecentAttraction.fromJson)
        .toList();
  }

  @override
  Future<void> clearRecentAttractions() async {
    final response = await _delete<Map<String, dynamic>>(
        AppConfig.recentAttractionsEndpoint);
    _unwrap(response, errorMessage: '최근 본 관광지를 삭제하지 못했어요.');
  }

  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _guard(() => _dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> _delete<T>(String path) =>
      _guard(() => _dio.delete<T>(path));

  Future<Response<T>> _guard<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (e) {
      final envelope = e.response?.data;
      final message = envelope is Map<String, dynamic>
          ? envelope['message'] as String?
          : null;
      throw AttractionsApiException(
        message ?? '요청을 처리하지 못했어요.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// 공통 응답 봉투를 언래핑한다(`ChatApi._unwrap`과 동일한 규칙).
  Map<String, dynamic> _unwrap(
    Response<Map<String, dynamic>> response, {
    required String errorMessage,
  }) {
    final envelope = response.data;
    if (envelope?['success'] != true) {
      throw AttractionsApiException(
        envelope?['message'] as String? ?? errorMessage,
        retriable: envelope?['retriable'] as bool? ?? false,
      );
    }
    return envelope?['data'] as Map<String, dynamic>? ?? const {};
  }
}
