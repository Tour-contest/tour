import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// docs/DESIGN.md: "답변 완료 후 액션: 복사(클릭 시 '복사됨' 1.5초) · 다시 생성".
class MessageActionsRow extends StatefulWidget {
  const MessageActionsRow(
      {super.key, required this.textToCopy, required this.onRegenerate});

  final String textToCopy;
  final VoidCallback onRegenerate;

  @override
  State<MessageActionsRow> createState() => _MessageActionsRowState();
}

class _MessageActionsRowState extends State<MessageActionsRow> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.textToCopy));
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _ActionButton(
            icon: AppIconShape.copy,
            label: _copied ? '복사됨' : '복사',
            onTap: _handleCopy,
          ),
          const SizedBox(width: 16),
          _ActionButton(
            icon: AppIconShape.refresh,
            label: '다시 생성',
            onTap: widget.onRegenerate,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  final AppIconShape icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 12, color: colors.ink600),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.body(fontSize: 10, color: colors.ink600)),
          ],
        ),
      ),
    );
  }
}
