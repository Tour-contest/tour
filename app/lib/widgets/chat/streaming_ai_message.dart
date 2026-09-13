import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/nullnull/alternative_card.dart';
import 'package:nullnull/widgets/nullnull/chat_card_view.dart';
import 'package:nullnull/widgets/nullnull/forecast_card.dart';
import 'package:nullnull/widgets/nullnull/no_data_card.dart';
import 'package:nullnull/widgets/nullnull/region_card.dart';

class StreamingAiMessage extends StatefulWidget {
  const StreamingAiMessage({
    super.key,
    required this.blocks,
    required this.streaming,
    this.onActionTap,
  });

  /// SSE로 도착하는 대로(실시간으로) 자라는 블록 목록. 호출부가 새 델타/카드를
  /// 받을 때마다 `setState`로 이 목록을 갱신하면 그대로 반영된다.
  final List<AiBlock> blocks;

  /// 아직 스트림이 끝나지 않았는지. `true`인 동안에는 마지막 문장 블록 끝에
  /// 깜빡이는 커서를 붙여 "아직 응답이 오는 중"임을 보여준다.
  final bool streaming;
  final ValueChanged<String>? onActionTap;

  /// 액션(복사) 등에서 쓸 순수 텍스트.
  static String plainText(List<AiBlock> blocks) {
    return blocks.whereType<TextBlock>().map((b) => b.text).join('\n\n');
  }

  @override
  State<StreamingAiMessage> createState() => _StreamingAiMessageState();
}

/// 텍스트를 가짜로 타이핑하듯 흉내 내지 않는다 — [widget.blocks]가 실제 SSE
/// 델타를 이어붙인 진짜 텍스트이므로, 네트워크로 도착하는 속도 자체가 이미
/// "타이핑" 효과다. 여기서는 스트리밍 중임을 보여주는 커서 깜빡임만 관리한다.
class _StreamingAiMessageState extends State<StreamingAiMessage> {
  bool _caretOn = true;
  Timer? _caretTimer;

  @override
  void initState() {
    super.initState();
    _syncCaretTimer();
  }

  @override
  void didUpdateWidget(covariant StreamingAiMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streaming != widget.streaming) _syncCaretTimer();
  }

  void _syncCaretTimer() {
    _caretTimer?.cancel();
    _caretTimer = null;
    if (!widget.streaming) return;
    _caretTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _caretOn = !_caretOn);
    });
  }

  @override
  void dispose() {
    _caretTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final blocks = widget.blocks;
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
          _BlockView(
            block: blocks[i],
            first: i == 0,
            showCaret: widget.streaming &&
                _caretOn &&
                i == blocks.length - 1 &&
                blocks[i] is TextBlock,
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
    this.showCaret = false,
    this.onActionTap,
  });

  final AiBlock block;
  final bool first;
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
                TextSpan(text: text),
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
      final ChatCardBlock cardBlock => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ChatCardView(block: cardBlock),
        ),
    };
  }
}
