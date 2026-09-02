import 'package:dio/dio.dart';

import 'package:nullnull/app_config.dart';

/// [AppConfig]의 서버 설정을 적용한 공용 [Dio] 인스턴스를 만든다.
/// 아직 이 인스턴스를 실제로 사용하는 API 구현체(예: `DioChatApi`)는 어디서도 생성되지 않는다.
class ApiClient {
  ApiClient._();

  static Dio create() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
      ),
    );
  }
}
