import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nullnull/data/speech_to_text_service.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/voice_listening_toast.dart';

/// docs/DESIGN.md: "입력바(상단 헤어라인): 첨부 클립 아이콘 · pill 입력창 · 원형 전송 버튼".
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.isGenerating = false,
    this.onStop,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  /// AI 응답이 현재 생성 중인지. `true`면 전송 버튼이 정지 아이콘
  /// (`chat_stop.svg`)으로 바뀌고, 탭/엔터 시 [onSend] 대신 [onStop]을
  /// 호출한다(사용자 요청 — 응답 생성 중에도 다른 메시지를 보낼 수 없게
  /// 막고, 대신 지금 생성 중인 응답을 멈출 수 있게 함). 입력창(`TextField`)도
  /// 이 값이 `true`인 동안 `enabled: false`로 비활성화한다(사용자 요청).
  final bool isGenerating;

  /// [isGenerating]이 `true`일 때 정지 버튼 탭 시 호출된다.
  final VoidCallback? onStop;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _focusNode = FocusNode();
  bool _focused = false;

  final _speechToText = SpeechToTextService();
  bool _isListening = false;
  String _voiceInputBase = '';

  @override
  void initState() {
    super.initState();
    _focusNode
        .addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _speechToText.cancel();
    VoiceListeningToast.dismiss();
    super.dispose();
  }

  void _submit() {
    if (widget.isGenerating) return;
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    widget.controller.clear();
    _focusNode.unfocus();
  }

  /// 마이크 아이콘 탭 시 음성 입력을 시작/중지한다. 인식 중간 결과가 나올 때마다
  /// 입력창 텍스트를 갱신하며, 탭 당시 이미 입력돼 있던 텍스트 뒤에 이어붙인다.
  /// 최종 결과(`isFinal`)가 나오면 음성 입력을 멈추고 곧바로 전송까지
  /// 트리거한다(엔터를 직접 치는 것과 동일) — 최종 결과가 빈 문자열이면
  /// `_submit`의 빈 텍스트 가드에 걸려 아무 일도 일어나지 않는다. 권한 거부로
  /// 초기화 자체가 실패하면 `chatInputVoiceUnavailable` 토스트를, 권한은 있지만
  /// 듣는 도중 오류(네트워크 오류·인식 타임아웃 등)로 중단되면
  /// `chatInputVoiceError` 토스트를 띄운다(전자는 아직 `_isListening`이 켜지기
  /// 전이라 구분됨).
  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _stopVoiceInput();
      return;
    }

    final unavailableMessage =
        AppLocalizations.of(context)!.chatInputVoiceUnavailable;
    final errorMessage = AppLocalizations.of(context)!.chatInputVoiceError;
    final available = await _speechToText.initialize(
      onError: (_) {
        // 권한 거부는 `initialize()`가 `false`를 반환하는 시점(아래)에서 이미
        // 처리하므로, 여기서는 그 이후(`_isListening`이 켜진 뒤) 듣는 도중
        // 발생하는 오류만 다룬다.
        if (!mounted || !_isListening) return;
        _stopVoiceInput();
        AppToast.show(errorMessage, type: AppToastType.info);
      },
    );
    if (!available) {
      AppToast.show(unavailableMessage, type: AppToastType.info);
      return;
    }

    _voiceInputBase = widget.controller.text;
    setState(() => _isListening = true);
    VoiceListeningToast.show(onTap: _stopVoiceInput);
    await _speechToText.startListening(
      onResult: (text, isFinal) {
        final combined =
            _voiceInputBase.isEmpty ? text : '$_voiceInputBase $text';
        widget.controller.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
        if (isFinal) {
          _stopVoiceInput();
          _submit();
        }
      },
    );
  }

  Future<void> _stopVoiceInput() async {
    VoiceListeningToast.dismiss();
    await _speechToText.stopListening();
    if (mounted) setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      color: colors.loginBackground,
      child: Container(
        // height: 46,
        padding: const EdgeInsets.fromLTRB(20, 9, 9, 9),
        decoration: BoxDecoration(
          color: colors.inputBar,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: _focused ? colors.accent : colors.inputBarBorder,
              width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: !widget.isGenerating,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                style: AppTextStyles.body(fontSize: 16, color: colors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.chatInputHint,
                  hintStyle:
                      AppTextStyles.body(fontSize: 15, color: colors.ink600),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: l10n.chatInputVoiceTooltip,
              child: GestureDetector(
                onTap: _toggleVoiceInput,
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset('assets/images/mic.svg'),
              ),
            ),
            const SizedBox(width: 9),
            Tooltip(
              message: widget.isGenerating
                  ? l10n.chatInputStopTooltip
                  : l10n.chatInputSendTooltip,
              child: GestureDetector(
                onTap: widget.isGenerating ? widget.onStop : _submit,
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset(widget.isGenerating
                    ? 'assets/images/chat_stop.svg'
                    : 'assets/images/chat_submit.svg'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
