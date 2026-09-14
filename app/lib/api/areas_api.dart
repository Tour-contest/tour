import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/demo_script.dart' show Level;

/// `GET /api/v1/areas`/`.../resolve`의 시군구 한 건. `docs/API_SPEC.md`에 예시
/// 페이로드가 없어 필드명은 이미 확정된 `card.payload`(`attraction_list`/`crowd`)의
/// `signgu_cd`/`signgu_nm` 표기를 따르고, 시도 필드명(`sido_cd`/`sido_nm`)은 같은
/// 명명 규칙을 근거로 가정했다 — 실제 응답으로 확인되면 이 `fromJson`만 갱신하면 됨.
class AreaCode {
  const AreaCode({
    required this.signguCd,
    required this.signguNm,
    this.sidoCd,
    this.sidoNm,
  });

  factory AreaCode.fromJson(Map<String, dynamic> json) {
    return AreaCode(
      signguCd: json['signgu_cd'] as String? ?? '',
      signguNm: json['signgu_nm'] as String? ?? '',
      sidoCd: json['sido_cd'] as String?,
      sidoNm: json['sido_nm'] as String?,
    );
  }

  final String signguCd;
  final String signguNm;
  final String? sidoCd;
  final String? sidoNm;
}

/// `GET /api/v1/areas/resolve`의 결과. [status]가 `ambiguous`면 [candidates]가
/// 채워지고, 절대 `candidates.first`를 임의로 선택해선 안 된다(`docs/API_SPEC.md`의
/// "구현 주의") — 호출부가 선택 UI를 보여줘야 한다. `ok`/`ambiguous` 외 다른
/// `status` 값(예: 못 찾았을 때)은 아직 확인된 바 없어 가정이다.
class AreaResolveResult {
  const AreaResolveResult({required this.status, this.area, this.candidates});

  factory AreaResolveResult.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>?;
    return AreaResolveResult(
      status: json['status'] as String? ?? '',
      area: json['signgu_cd'] != null ? AreaCode.fromJson(json) : null,
      candidates: candidates
          ?.cast<Map<String, dynamic>>()
          .map(AreaCode.fromJson)
          .toList(),
    );
  }

  final String status;
  final AreaCode? area;
  final List<AreaCode>? candidates;
}

/// `crowd` 카드(`docs/API_SPEC.md`의 `### chat`에서 확인된 스키마)의 `samples`
/// 항목과 동일한 모양. `overview`/`crowding` 엔드포인트가 그 카드를 만드는 데
/// 쓰이는 원자료일 가능성이 높아 필드명을 그대로 따랐다.
class AreaCrowdSample {
  const AreaCrowdSample({
    required this.contentId,
    required this.name,
    required this.rate,
    this.image,
  });

  factory AreaCrowdSample.fromJson(Map<String, dynamic> json) {
    return AreaCrowdSample(
      contentId: json['content_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      rate: ((json['rate'] as num?) ?? 0).round(),
      image: json['image'] as String?,
    );
  }

  final String contentId;
  final String name;
  final int rate;
  final String? image;
}

/// `GET /api/v1/areas/{signgu_cd}/overview`·`.../crowding` 공통 응답(`docs/API_SPEC.md`에
/// "overview와 응답 스키마 동일"이라고 명시됨). `summary`/`samples`의 키(`혼잡`/`보통`/
/// `한적`)를 [Level]로 매핑하는 것도 `crowd` 카드와 동일한 규칙을 따른다.
class AreaCrowdSnapshot {
  const AreaCrowdSnapshot({
    required this.signguCd,
    required this.signguNm,
    required this.date,
    required this.counts,
    required this.samples,
  });

  factory AreaCrowdSnapshot.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    final samplesJson = json['samples'] as Map<String, dynamic>? ?? const {};
    final counts = <Level, int>{};
    summary.forEach((key, value) {
      counts[_levelFor(key)] = (value as num?)?.toInt() ?? 0;
    });
    final samples = <Level, List<AreaCrowdSample>>{};
    samplesJson.forEach((key, value) {
      samples[_levelFor(key)] = ((value as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AreaCrowdSample.fromJson)
          .toList();
    });
    return AreaCrowdSnapshot(
      signguCd: json['signgu_cd'] as String? ?? '',
      signguNm: json['signgu_nm'] as String? ?? '',
      date: json['date'] as String?,
      counts: counts,
      samples: samples,
    );
  }

  static Level _levelFor(String koreanLabel) => switch (koreanLabel) {
        '혼잡' => Level.busy,
        '한적' => Level.quiet,
        _ => Level.normal,
      };

  final String signguCd;
  final String signguNm;
  final String? date;
  final Map<Level, int> counts;
  final Map<Level, List<AreaCrowdSample>> samples;
}

/// `GET /api/v1/areas/{signgu_cd}/visitors`의 주 단위 방문자 수 한 건. 필드명은
/// 아직 예시가 없어 가정이다.
class WeeklyVisitorPoint {
  const WeeklyVisitorPoint({required this.weekStart, required this.visitors});

  factory WeeklyVisitorPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyVisitorPoint(
      weekStart:
          DateTime.tryParse(json['week_start'] as String? ?? '')?.toLocal(),
      visitors: ((json['visitors'] as num?) ?? 0).toInt(),
    );
  }

  final DateTime? weekStart;
  final int visitors;
}

/// `GET /api/v1/areas/{signgu_cd}/visitors` 응답. `docs/API_SPEC.md`가 "약 2개월
/// 지연 데이터, `data_through` 필수 표시"라고 못박아둔 만큼, 이 추이를 그리는
/// 화면은 [dataThrough]를 반드시 함께 보여줘야 한다.
class AreaVisitorsTrend {
  const AreaVisitorsTrend({required this.dataThrough, required this.points});

  factory AreaVisitorsTrend.fromJson(Map<String, dynamic> json) {
    return AreaVisitorsTrend(
      dataThrough:
          DateTime.tryParse(json['data_through'] as String? ?? '')?.toLocal(),
      points: ((json['items'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(WeeklyVisitorPoint.fromJson)
          .toList(),
    );
  }

  final DateTime? dataThrough;
  final List<WeeklyVisitorPoint> points;
}

/// [AreasApi] 호출이 실패(`success: false`, 혹은 4xx/5xx HTTP 상태)했을 때
/// 던지는 예외. [statusCode]는 HTTP 상태 코드가 있을 때만 채워진다(`content_id`
/// 상세 조회의 404/503처럼, 호출부가 이후 하위 조회를 계속할지 판단하는 데 씀).
class AreasApiException implements Exception {
  AreasApiException(this.message, {this.retriable = false, this.statusCode});
  final String message;
  final bool retriable;
  final int? statusCode;

  @override
  String toString() => message;
}

/// `docs/API_SPEC.md`의 `### areas` 절 API(`lib/api/chat_api.dart`의 `ChatApi`와
/// 동일한 봉투 언래핑 패턴). 아직 실서버로 필드명을 확인하지 못한 부분은 각
/// 모델 클래스 문서에 가정임을 남겨뒀다.
abstract class AreasApi {
  /// `GET /api/v1/areas`(캐시 가능한 기준정보).
  Future<List<AreaCode>> fetchAreas();

  /// `GET /api/v1/areas/resolve?q=`. `status: ambiguous`일 때 절대 자동으로
  /// [AreaResolveResult.candidates]의 첫 항목을 선택하지 말 것 — 호출부가
  /// 선택 UI로 분기해야 한다.
  Future<AreaResolveResult> resolve({required String query});

  /// `GET /api/v1/areas/{signgu_cd}/overview?date=`. [date]를 비우면 서버
  /// 기준(KST) 오늘로 조회된다.
  Future<AreaCrowdSnapshot> fetchOverview({
    required String signguCd,
    DateTime? date,
  });

  /// `GET /api/v1/areas/{signgu_cd}/crowding?date=`. 응답 스키마는 [fetchOverview]와
  /// 동일하다(`docs/API_SPEC.md`).
  Future<AreaCrowdSnapshot> fetchCrowding({
    required String signguCd,
    DateTime? date,
  });

  /// `GET /api/v1/areas/{signgu_cd}/visitors?weeks=`.
  Future<AreaVisitorsTrend> fetchVisitors({
    required String signguCd,
    int? weeks,
  });
}

/// [AreasApi] 호출/응답을 [AppLog.logger]로 남기는 데코레이터(`LoggingChatApi`와
/// 동일한 패턴).
class LoggingAreasApi implements AreasApi {
  LoggingAreasApi(this._inner);

  final AreasApi _inner;

  @override
  Future<List<AreaCode>> fetchAreas() async {
    AppLog.logger.i('[AreasApi] fetchAreas');
    try {
      final areas = await _inner.fetchAreas();
      AppLog.logger.d('[AreasApi] ← ${areas.length}건');
      return areas;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[AreasApi] fetchAreas 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AreaResolveResult> resolve({required String query}) async {
    AppLog.logger.i('[AreasApi] resolve → query: "$query"');
    try {
      final result = await _inner.resolve(query: query);
      AppLog.logger.d(
          '[AreasApi] ← status: ${result.status}, candidates: ${result.candidates?.length}');
      return result;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[AreasApi] resolve 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AreaCrowdSnapshot> fetchOverview({
    required String signguCd,
    DateTime? date,
  }) async {
    AppLog.logger
        .i('[AreasApi] fetchOverview → signguCd: $signguCd, date: $date');
    try {
      final snapshot =
          await _inner.fetchOverview(signguCd: signguCd, date: date);
      AppLog.logger.d('[AreasApi] ← counts: ${snapshot.counts}');
      return snapshot;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[AreasApi] fetchOverview 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AreaCrowdSnapshot> fetchCrowding({
    required String signguCd,
    DateTime? date,
  }) async {
    AppLog.logger
        .i('[AreasApi] fetchCrowding → signguCd: $signguCd, date: $date');
    try {
      final snapshot =
          await _inner.fetchCrowding(signguCd: signguCd, date: date);
      AppLog.logger.d('[AreasApi] ← counts: ${snapshot.counts}');
      return snapshot;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[AreasApi] fetchCrowding 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<AreaVisitorsTrend> fetchVisitors({
    required String signguCd,
    int? weeks,
  }) async {
    AppLog.logger
        .i('[AreasApi] fetchVisitors → signguCd: $signguCd, weeks: $weeks');
    try {
      final trend =
          await _inner.fetchVisitors(signguCd: signguCd, weeks: weeks);
      AppLog.logger.d(
          '[AreasApi] ← points: ${trend.points.length}건, dataThrough: ${trend.dataThrough}');
      return trend;
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[AreasApi] fetchVisitors 실패', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

/// [AppConfig]의 `area*Endpoint`로 실제 요청을 보내는 구현.
class DioAreasApi implements AreasApi {
  DioAreasApi(this._dio);

  final Dio _dio;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  Future<List<AreaCode>> fetchAreas() async {
    final response = await _get<Map<String, dynamic>>(AppConfig.areasEndpoint);
    final data = _unwrap(response, errorMessage: '지역 목록을 불러오지 못했어요.');
    return ((data['items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AreaCode.fromJson)
        .toList();
  }

  @override
  Future<AreaResolveResult> resolve({required String query}) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.areasResolveEndpoint,
      queryParameters: {'q': query},
    );
    final data = _unwrap(response, errorMessage: '지역을 찾지 못했어요.');
    return AreaResolveResult.fromJson(data);
  }

  @override
  Future<AreaCrowdSnapshot> fetchOverview({
    required String signguCd,
    DateTime? date,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.areaOverviewEndpoint(signguCd),
      queryParameters: _dateQuery(date: date),
    );
    final data = _unwrap(response, errorMessage: '지역 현황을 불러오지 못했어요.');
    return AreaCrowdSnapshot.fromJson(data);
  }

  @override
  Future<AreaCrowdSnapshot> fetchCrowding({
    required String signguCd,
    DateTime? date,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.areaCrowdingEndpoint(signguCd),
      queryParameters: _dateQuery(date: date),
    );
    final data = _unwrap(response, errorMessage: '혼잡도를 불러오지 못했어요.');
    return AreaCrowdSnapshot.fromJson(data);
  }

  @override
  Future<AreaVisitorsTrend> fetchVisitors({
    required String signguCd,
    int? weeks,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      AppConfig.areaVisitorsEndpoint(signguCd),
      queryParameters: weeks == null ? null : {'weeks': weeks},
    );
    final data = _unwrap(response, errorMessage: '방문자 추이를 불러오지 못했어요.');
    return AreaVisitorsTrend.fromJson(data);
  }

  Map<String, dynamic>? _dateQuery({DateTime? date}) =>
      date == null ? null : {'date': _dateFormat.format(date)};

  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      final envelope = e.response?.data;
      final message = envelope is Map<String, dynamic>
          ? envelope['message'] as String?
          : null;
      throw AreasApiException(
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
      throw AreasApiException(
        envelope?['message'] as String? ?? errorMessage,
        retriable: envelope?['retriable'] as bool? ?? false,
      );
    }
    return envelope?['data'] as Map<String, dynamic>? ?? const {};
  }
}
