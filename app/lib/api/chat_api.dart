import 'package:dio/dio.dart';

import 'package:nullnull/app_config.dart';
import 'package:nullnull/data/demo_script.dart';

/// 채팅 메시지 전송 · AI 응답 조회 API. 실제 백엔드 연동 전까지는 [MockChatApi]를 사용한다.
abstract class ChatApi {
  Future<AiTurn> sendMessage(String text, {required int turnIndex});
}

/// `docs/DESIGN.md`의 데모 시나리오([DemoScript])를 그대로 반환하는 목업 구현.
class MockChatApi implements ChatApi {
  @override
  Future<AiTurn> sendMessage(String text, {required int turnIndex}) async {
    return DemoScript.turnFor(turnIndex);
  }
}

/// [AppConfig.chatMessageEndpoint]로 실제 요청을 보내는 구현.
/// API 연동 명세서가 확정되지 않아 응답 파싱은 아직 없고, 어디서도 생성되지 않는다.
class DioChatApi implements ChatApi {
  DioChatApi(this._dio);

  final Dio _dio;

  @override
  Future<AiTurn> sendMessage(String text, {required int turnIndex}) async {
    await _dio.post<Map<String, dynamic>>(
      AppConfig.chatMessageEndpoint,
      data: {'message': text},
    );
    throw UnimplementedError('API 연동 명세서 확정 후 응답 파싱 구현 필요');
  }
}
