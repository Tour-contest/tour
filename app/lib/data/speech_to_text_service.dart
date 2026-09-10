import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:nullnull/app_log.dart';

/// `ChatInputBar`의 음성 입력 버튼이 사용하는 STT(Speech-to-Text) 래퍼.
/// `speech_to_text` 패키지가 기기 내장 음성인식 엔진(Apple Speech / Android
/// SpeechRecognizer)을 사용하며, 마이크·음성인식 권한 요청도 내부에서 처리한다.
class SpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// 기기가 음성인식을 지원하고 권한이 허용됐는지 확인 후 초기화한다.
  /// 지원하지 않거나 권한이 거부되면 false를 반환한다.
  Future<bool> initialize() async {
    try {
      return await _speech.initialize(
        onError: (error) => AppLog.logger.e('STT 오류: ${error.errorMsg}'),
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
