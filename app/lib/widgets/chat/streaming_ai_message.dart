import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/alternative_card.dart';
import 'package:nullnull/widgets/nullnull/forecast_card.dart';
import 'package:nullnull/widgets/nullnull/no_data_card.dart';
import 'package:nullnull/widgets/nullnull/region_card.dart';

class StreamingAiMessage extends StatefulWidget {
  const StreamingAiMessage({
    super.key,
    required this.turn,
    this.onComplete,
    this.onActionTap,
  });

  final AiTurn turn;
  final VoidCallback? onComplete;
  final ValueChanged<String>? onActionTap;

  /// 액션(복사) 등에서 쓸 순수 텍스트.
  static String plainText(AiTurn turn) {
    return turn.blocks.whereType<TextBlock>().map((b) => b.text).join('\n\n');
  }

  @override
  State<StreamingAiMessage> createState() => _StreamingAiMessageState();
}

class _StreamingAiMessageState extends State<StreamingAiMessage> {
  int _blockIndex = 0;
  int _charsRevealed = 0;
  bool _done = false;
  bool _caretOn = true;
  Timer? _typeTimer;
  Timer? _caretTimer;

  @override
  void initState() {
    super.initState();
    _typeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _caretTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted || _done) return;
      setState(() => _caretOn = !_caretOn);
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _caretTimer?.cancel();
    super.dispose();
  }

  void _tick() {
    final blocks = widget.turn.blocks;
    if (_blockIndex >= blocks.length) {
      _finish();
      return;
    }
    final block = blocks[_blockIndex];
    if (block is TextBlock) {
      final next = _charsRevealed + 2;
      if (next >= block.text.length) {
        _blockIndex++;
        _charsRevealed = 0;
        setState(() {});
        if (_blockIndex >= blocks.length) _finish();
      } else {
        setState(() => _charsRevealed = next);
      }
    } else {
      _blockIndex++;
      _charsRevealed = 0;
      setState(() {});
      if (_blockIndex >= blocks.length) _finish();
    }
  }

  void _finish() {
    _typeTimer?.cancel();
    _typeTimer = null;
    _caretTimer?.cancel();
    if (mounted) {
      setState(() => _done = true);
    } else {
      _done = true;
    }
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final blocks = widget.turn.blocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '널널',
              style: AppTextStyles.body(
                fontSize: 9.5,
                color: colors.accentBright,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < blocks.length; i++)
          if (i < _blockIndex)
            _BlockView(
                block: blocks[i],
                first: i == 0,
                onActionTap: widget.onActionTap)
          else if (i == _blockIndex && !_done)
            _BlockView(
              block: blocks[i],
              first: i == 0,
              partialChars: blocks[i] is TextBlock ? _charsRevealed : null,
              showCaret: blocks[i] is TextBlock && _caretOn,
              onActionTap: widget.onActionTap,
            ),
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.first,
    this.partialChars,
    this.showCaret = false,
    this.onActionTap,
  });

  final AiBlock block;
  final bool first;
  final int? partialChars;
  final bool showCaret;
  final ValueChanged<String>? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return switch (block) {
      TextBlock(:final text) => Padding(
          padding: EdgeInsets.only(top: first ? 0 : 10),
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.body(color: colors.ink, height: 1.8),
              children: [
                TextSpan(
                    text: partialChars == null
                        ? text
                        : text.substring(0, partialChars!)),
                if (showCaret)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      width: 6,
                      height: 13,
                      margin: const EdgeInsets.only(left: 2),
                      color: colors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ForecastBlock(:final forecast) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForecastCard(forecast: forecast),
        ),
      AlternativesBlock(:final items, :final excludedNote) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AlternativesSection(items: items, excludedNote: excludedNote),
        ),
      RegionBlock(:final status) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: RegionCard(status: status),
        ),
      NoDataBlock(:final actions) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: NoDataCard(
            actions: actions,
            onActionTap: onActionTap ?? (_) {},
          ),
        ),
    };
  }
}
