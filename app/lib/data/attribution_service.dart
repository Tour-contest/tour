import 'package:dio/dio.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';

/// `docs/API_SPEC.md`의 `GET /api/v1/meta/attribution`(출처 표기 문구 조회, `data.text`)을
/// 호출해 [text]에 전역으로 저장해두는 정적 유틸리티. `health_check_gate.dart`의
/// `HealthCheckGate`가 헬스 체크 성공 시 [fetch]를 호출한다. 앱이 아직 [fetch]를 호출하지
/// 않았거나 조회에 실패했다면 [text]는 `null`이며, 화면에서는 이 경우 해당 문구를 노출하지
/// 않으면 된다.
class AttributionService {
  AttributionService._();

  static String? _text;

  /// 출처 표기 문구. [fetch]가 성공하기 전이거나 실패했다면 `null`.
  static String? get text => _text;

  static Future<void> fetch() async {
    try {
      final response = await ApiClient.create()
          .get<Map<String, dynamic>>(AppConfig.attributionEndpoint);
      if (response.data?['success'] != true) return;
      final data = response.data?['data'] as Map<String, dynamic>?;
      _text = data?['text'] as String?;
    } on DioException catch (e, stackTrace) {
      AppLog.logger.e('출처 표기 문구 조회 실패', error: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      AppLog.logger
          .e('출처 표기 문구 조회 중 알 수 없는 오류', error: e, stackTrace: stackTrace);
    }
  }
}
