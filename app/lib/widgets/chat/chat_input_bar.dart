import 'package:flutter/material.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

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

  @override
  void initState() {
    super.initState();
    _focusNode
        .addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: AppIcon(AppIconShape.clip, color: colors.ink700),
              onPressed: () {},
              tooltip: l10n.chatInputAttachTooltip,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border:
                    Border.all(color: _focused ? colors.gold : colors.divider),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                style: AppTextStyles.body(fontSize: 13.5, color: colors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.chatInputHint,
                  hintStyle:
                      AppTextStyles.body(fontSize: 13.5, color: colors.ink600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            height: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.gold),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: AppIcon(AppIconShape.arrowUp,
                    size: 14, color: colors.gold700),
                onPressed: _submit,
                tooltip: l10n.chatInputSendTooltip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
