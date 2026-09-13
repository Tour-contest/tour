import 'package:dio/dio.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/auth_service.dart';
import 'package:nullnull/data/auth_token_storage.dart';

/// [AppConfig]의 서버 설정을 적용한 공용 [Dio] 인스턴스를 만든다. [AuthTokenStorage]에
/// 저장된 액세스 토큰이 있으면 [_AuthInterceptor]가 모든 요청에
/// `Authorization: Bearer <token>`을 자동으로 실어 보낸다(`docs/API_SPEC.md`의
/// `### 인증` 규칙). `healthz`/`attribution`처럼 인증이 필요 없는 엔드포인트에도
/// 헤더가 함께 실리지만 서버가 무시하므로 문제없다. 401을 받으면 [AuthService.refresh]로
/// 딱 1회 갱신을 시도한 뒤 원래 요청을 재시도한다(그마저 실패하면 원래 401을 그대로
/// 전달 — 재시도 요청이 다시 401이면 무한 루프 대신 `options.extra`의 표시로 한
/// 번만 재시도한다).
class ApiClient {
  ApiClient._();

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
      ),
    );
    dio.interceptors.add(_AuthInterceptor(dio));
    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;

  static const _retriedKey = 'authRetried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await AuthTokenStorage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final alreadyRetried = options.extra[_retriedKey] == true;
    final isRefreshCall = options.path == AppConfig.authRefreshEndpoint;
    if (err.response?.statusCode != 401 || alreadyRetried || isRefreshCall) {
      handler.next(err);
      return;
    }

    AppLog.logger
        .w('[Auth] ${options.method} ${options.path} 401 → refresh 시도');
    try {
      await AuthService.refresh();
    } catch (e, stackTrace) {
      AppLog.logger
          .e('[Auth] refresh 실패 → 원래 401 전달', error: e, stackTrace: stackTrace);
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
      final response = await _dio.fetch<dynamic>(options);
      AppLog.logger
          .i('[Auth] refresh 성공, ${options.method} ${options.path} 재시도 성공');
      handler.resolve(response);
    } on DioException catch (e) {
      AppLog.logger.e('[Auth] refresh 후 재시도도 실패', error: e);
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}
