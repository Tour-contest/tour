import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:nullnull/app_log.dart';

/// `ChatInputBar`의 음성 입력 버튼이 사용하는 STT(Speech-to-Text) 래퍼.
/// `speech_to_text` 패키지가 기기 내장 음성인식 엔진(Apple Speech / Android
/// SpeechRecognizer)을 사용하며, 마이크·음성인식 권한 요청도 내부에서 처리한다.
class SpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// 기기가 음성인식을 지원하고 권한이 허용됐는지 확인 후 초기화한다.
  /// 지원하지 않거나 권한이 거부되면 false를 반환한다(권한 거부 케이스는 이
  /// 반환값으로 이미 구분되므로, [onError]는 호출되지 않는다). [onError]는
  /// 그 이후 듣는 도중 발생하는 오류(네트워크 오류, 인식 타임아웃 등 —
  /// `speech_to_text` 패키지가 이 시점부터 세션이 끝났다고 판단해 듣기가
  /// 자동으로 중단됨)를 알려준다.
  Future<bool> initialize({void Function(String errorMsg)? onError}) async {
    try {
      return await _speech.initialize(
        onError: (error) {
          AppLog.logger.e('STT 오류: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
      );
    } catch (error) {
      AppLog.logger.e('STT 초기화 실패', error: error);
      return false;
    }
  }

  /// 인식 결과가 나올 때마다(중간 결과 포함) [onResult]로 전달한다.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
  }) {
    return _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'ko_KR'),
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
    );
  }

  Future<void> stopListening() => _speech.stop();

  void cancel() => _speech.cancel();
}
