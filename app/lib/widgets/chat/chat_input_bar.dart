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
  const ChatInputBar(
      {super.key, required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

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
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    widget.controller.clear();
  }

  /// 마이크 아이콘 탭 시 음성 입력을 시작/중지한다. 인식 중간 결과가 나올 때마다
  /// 입력창 텍스트를 갱신하며, 탭 당시 이미 입력돼 있던 텍스트 뒤에 이어붙인다.
  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _stopVoiceInput();
      return;
    }

    final unavailableMessage =
        AppLocalizations.of(context)!.chatInputVoiceUnavailable;
    final available = await _speechToText.initialize();
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
        if (isFinal) _stopVoiceInput();
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
              message: l10n.chatInputSendTooltip,
              child: GestureDetector(
                onTap: _submit,
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset('assets/images/chat_submit.svg'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
