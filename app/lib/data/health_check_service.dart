import 'package:dio/dio.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';

/// 앱 실행 시 백엔드 헬스 체크(`docs/API_SPEC.md`의 `GET /api/v1/healthz`)를 수행한다.
/// 인증이 필요 없는 엔드포인트이므로 별도 토큰 없이 [ApiClient.create]를 그대로 사용한다.
class HealthCheckService {
  HealthCheckService._();

  /// 응답 봉투(Envelope)의 `success`가 `true`이면 정상, 그 외(요청 실패 포함)에는
  /// `false`를 반환한다. 헬스 체크는 데이터 유무를 다루지 않으므로 `data.status`는
  /// 확인하지 않는다.
  static Future<bool> check() async {
    try {
      final response = await ApiClient.create()
          .get<Map<String, dynamic>>(AppConfig.healthzEndpoint);
      return response.data?['success'] == true;
    } on DioException catch (e, stackTrace) {
      AppLog.logger.e('헬스 체크 요청 실패', error: e, stackTrace: stackTrace);
      return false;
    } catch (e, stackTrace) {
      AppLog.logger.e('헬스 체크 중 알 수 없는 오류', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
