import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// docs/DESIGN.md: "AI 메시지" + "스트리밍: 글자 단위 타이핑(30ms, 2자씩) + 깜빡이는 골드 캐럿".
class StreamingAiMessage extends StatefulWidget {
  const StreamingAiMessage({super.key, required this.turn, this.onComplete});

  final AiTurn turn;
  final VoidCallback? onComplete;

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
                  BoxDecoration(color: colors.gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '널널',
              style: AppTextStyles.body(
                fontSize: 9.5,
                color: colors.gold700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < blocks.length; i++)
          if (i < _blockIndex)
            _BlockView(block: blocks[i], first: i == 0)
          else if (i == _blockIndex && !_done)
            _BlockView(
              block: blocks[i],
              first: i == 0,
              partialChars: blocks[i] is TextBlock ? _charsRevealed : null,
              showCaret: blocks[i] is TextBlock && _caretOn,
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
  });

  final AiBlock block;
  final bool first;
  final int? partialChars;
  final bool showCaret;

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
                      color: colors.gold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      PlaceListBlock(:final items) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Column(
              children: [for (final item in items) _PlaceRow(item: item)],
            ),
          ),
        ),
      CourseListBlock(:final items) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Column(
              children: [for (final step in items) _CourseRow(step: step)],
            ),
          ),
        ),
    };
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.item});

  final PlaceRecommendation item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style:
                      AppTextStyles.heading(fontSize: 15.5, color: colors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: AppTextStyles.body(
                      fontSize: 12, color: colors.ink700, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: colors.gold),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '혼잡도 ${item.congestionPercent}%',
              style: AppTextStyles.tabularNums(
                AppTextStyles.body(fontSize: 10.5, color: colors.gold700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.step});

  final CourseStep step;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              step.time,
              style: AppTextStyles.tabularNums(
                AppTextStyles.body(fontSize: 11, color: colors.gold700),
              ),
            ),
          ),
          Text(
            step.title,
            style: AppTextStyles.heading(fontSize: 15.5, color: colors.ink),
          ),
        ],
      ),
    );
  }
}
