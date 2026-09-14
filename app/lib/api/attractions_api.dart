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

/// `GET /api/v1/attractions/{content_id}`. 소개문 필드명(`overview`)은 아직
/// 예시가 없어 관광공사 TourAPI의 관례적인 필드명을 근거로 가정했다.
class AttractionDetail {
  const AttractionDetail({required this.summary, this.overview});

  factory AttractionDetail.fromJson(Map<String, dynamic> json) {
    return AttractionDetail(
      summary: AttractionSummary.fromJson(json),
      overview: json['overview'] as String?,
    );
  }

  final AttractionSummary summary;
  final String? overview;
}

/// `attractions/{content_id}/crowd`의 일자별 예측 혼잡도 한 건. [rate]는 `%`
/// 기호 없는 숫자(집중률)이고, [level]은 `혼잡`/`보통`/`한적` 세 값만
/// 온다(`docs/API_SPEC.md`).
class AttractionCrowdDay {
  const AttractionCrowdDay({
    required this.date,
    required this.rate,
    required this.level,
  });

  factory AttractionCrowdDay.fromJson(Map<String, dynamic> json) {
    return AttractionCrowdDay(
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      rate: ((json['rate'] as num?) ?? 0).round(),
      level: levelForKoreanLabel(json['level'] as String?),
    );
  }

  final DateTime? date;
  final int rate;
  final Level level;
}

/// 기간 요약(`days` 파라미터로 조회한 구간 전체의 평균 집중률/등급). 필드명은
/// 예시가 없어 가정이다.
class AttractionCrowdPeriodSummary {
  const AttractionCrowdPeriodSummary({
    required this.averageRate,
    required this.level,
  });

  factory AttractionCrowdPeriodSummary.fromJson(Map<String, dynamic> json) {
    return AttractionCrowdPeriodSummary(
      averageRate: ((json['average_rate'] as num?) ?? 0).round(),
      level: levelForKoreanLabel(json['level'] as String?),
    );
  }

  final int averageRate;
  final Level level;
}

class AttractionCrowdForecast {
  const AttractionCrowdForecast({required this.days, this.summary});

  factory AttractionCrowdForecast.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>?;
    return AttractionCrowdForecast(
      days: ((json['days'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AttractionCrowdDay.fromJson)
          .toList(),
      summary: summaryJson == null
          ? null
          : AttractionCrowdPeriodSummary.fromJson(summaryJson),
    );
  }

  final List<AttractionCrowdDay> days;
  final AttractionCrowdPeriodSummary? summary;
}

/// `attractions/{content_id}/alternatives`의 대안지 한 건. [rate]/[level]은
/// 그 대안지 자체의 혼잡도다. 목록 순서는 서버가 혼잡도 우선으로 이미 정렬해
/// 보내므로, 호출부는 유사도 등 다른 기준으로 **재정렬하면 안 된다**(`docs/API_SPEC.md`).
class AttractionAlternative {
  const AttractionAlternative({
    required this.summary,
    required this.rate,
    required this.level,
  });

  factory AttractionAlternative.fromJson(Map<String, dynamic> json) {
    return AttractionAlternative(
      summary: AttractionSummary.fromJson(json),
      rate: ((json['rate'] as num?) ?? 0).round(),
      level: levelForKoreanLabel(json['level'] as String?),
    );
  }

  final AttractionSummary summary;
  final int rate;
  final Level level;
}

/// 네이버 데이터랩 검색 관심도 추세(`attractions/{content_id}/interest`) 한
/// 지점. 필드명은 네이버 데이터랩 검색어 트렌드 API의 관례(`period`/`ratio`)를
/// 근거로 가정했다 — 이 프록시 엔드포인트가 그 값을 그대로 반환한다는 보장은
/// 없어 실제 응답 확인 전까지는 가정이다.
class InterestPoint {
  const InterestPoint({required this.period, required this.ratio});

  factory InterestPoint.fromJson(Map<String, dynamic> json) {
    return InterestPoint(
      period: DateTime.tryParse(json['period'] as String? ?? ''),
      ratio: ((json['ratio'] as num?) ?? 0).toDouble(),
    );
  }

  final DateTime? period;
  final double ratio;
}

class AttractionInterestTrend {
  const AttractionInterestTrend({required this.points});

  factory AttractionInterestTrend.fromJson(Map<String, dynamic> json) {
    return AttractionInterestTrend(
      points: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(InterestPoint.fromJson)
          .toList(),
    );
  }

  final List<InterestPoint> points;
}

/// `attractions/{content_id}/images`(캐러셀용 서브 이미지). 목록 자체가
/// 문자열 URL인지 객체인지 예시가 없어 두 형태 모두 허용해 문자열만 뽑아낸다.
class AttractionImages {
  const AttractionImages({required this.imageUrls});

  factory AttractionImages.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>?) ?? const [];
    return AttractionImages(
      imageUrls: items
          .map((item) =>
              item is String ? item : (item as Map<String, dynamic>)['url'])
          .whereType<String>()
          .toList(),
    );
  }

  final List<String> imageUrls;
}

/// `attractions/{content_id}/pet`(반려동물 동반 정보). `docs/API_SPEC.md`가
/// "`no_data` 흔함"이라고만 언급하고 세부 필드는 주지 않아, 개별 필드로 모델링하는
/// 대신 [status]만 뽑고 나머지는 [raw]에 그대로 담아둔다(`ChatToolEvent.raw`와
/// 동일한 이유) — 화면에서 실제로 어떤 필드를 보여줄지 정해지면 그때 구체화한다.
class AttractionPetInfo {
  const AttractionPetInfo({required this.status, required this.raw});

  factory AttractionPetInfo.fromJson(Map<String, dynamic> json) {
    return AttractionPetInfo(
        status: json['status'] as String? ?? '', raw: json);
  }

  final String status;
  final Map<String, dynamic> raw;

  bool get hasData => status != 'no_data';
}

/// `attractions/{content_id}/similar`(소개문 임베딩 코사인 유사도) 한 건.
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

  /// `GET /api/v1/attractions/{content_id}/alternatives?date=&limit=`. 응답
  /// 순서를 그대로 유지해야 한다(재정렬 금지).
  Future<List<AttractionAlternative>> fetchAlternatives({
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
  Future<List<AttractionAlternative>> fetchAlternatives({
    required String contentId,
    DateTime? date,
    int? limit,
  }) async {
    AppLog.logger.i(
        '[AttractionsApi] fetchAlternatives → contentId: $contentId, date: $date, limit: $limit');
    try {
      final alternatives = await _inner.fetchAlternatives(
          contentId: contentId, date: date, limit: limit);
      AppLog.logger.d('[AttractionsApi] ← ${alternatives.length}건');
      return alternatives;
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
      AppLog.logger.d('[AttractionsApi] ← ${trend.points.length}건');
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
  Future<List<AttractionAlternative>> fetchAlternatives({
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
    // 서버가 이미 혼잡도 우선으로 정렬해 보내므로 여기서 재정렬하지 않는다.
    return ((data['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AttractionAlternative.fromJson)
        .toList();
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
