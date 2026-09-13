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
    this.sources = const [],
    this.onActionTap,
    this.onRevealComplete,
    this.onRevealProgress,
  });

  /// 화면에 보여줄 블록 전체(완성된 응답). [streaming]이 `true`면 이 위젯이
  /// 직접 타이핑하듯 delay를 두고 하나씩 공개하고, `false`면(재생성/지난 대화
  /// 이어보기) 곧바로 전부 보여준다.
  final List<AiBlock> blocks;

  /// `true`면 방금 완성된 응답이라는 뜻으로, 위젯이 자체적으로 타이핑 연출을
  /// 시작한다. 연출이 끝나면 [onRevealComplete]를 호출한다.
  final bool streaming;

  /// `ChatSourcesEvent`로 받은 출처 목록(각 항목 `{name, note}`). 타이핑
  /// 연출이 다 끝난 뒤 응답 하단에 작게 보여준다.
  final List<Map<String, dynamic>> sources;

  final ValueChanged<String>? onActionTap;

  /// 타이핑 연출이 끝났을 때 호출된다(`_AiChatEntry.done`을 켜 커서를 멈추고
  /// 복사/재생성 버튼을 노출하는 데 쓰인다).
  final VoidCallback? onRevealComplete;

  /// 연출 도중 화면이 갱신될 때마다 호출된다(스크롤을 바닥으로 유지하는 데
  /// 쓰인다).
  final VoidCallback? onRevealProgress;

  /// 액션(복사) 등에서 쓸 순수 텍스트.
  static String plainText(List<AiBlock> blocks) {
    return blocks.whereType<TextBlock>().map((b) => b.text).join('\n\n');
  }

  @override
  State<StreamingAiMessage> createState() => _StreamingAiMessageState();
}

/// 타이핑 연출(delay를 두고 글자를 채워 넣는 것)을 이 위젯이 직접 담당한다.
/// [StreamingAiMessage.streaming]이 `true`로 처음 마운트되면 [widget.blocks]를
/// 한 글자씩 내부 [_visible] 목록에 옮겨 담고, `false`면(재생성/지난 대화
/// 이어보기) 연출 없이 곧바로 전부 보여준다.
class _StreamingAiMessageState extends State<StreamingAiMessage> {
  bool _caretOn = true;
  Timer? _caretTimer;
  final List<AiBlock> _visible = [];
  bool _revealed = false;

  /// 한 번에 몇 글자씩 보여줄지. 클수록 빠르게 타이핑되는 것처럼 보인다.
  static const _revealCharsPerTick = 2;
  static const _revealTickDelay = Duration(milliseconds: 20);

  /// 문장·카드 블록 사이에 두는 짧은 정지 — 카드가 툭 튀어나오지 않고 살짝
  /// 뜸을 들이는 것처럼 보이게 한다.
  static const _revealBlockGap = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    if (widget.streaming) {
      _syncCaretTimer();
      unawaited(_reveal());
    } else {
      _visible.addAll(widget.blocks);
      _revealed = true;
    }
  }

  @override
  void dispose() {
    _caretTimer?.cancel();
    super.dispose();
  }

  void _syncCaretTimer() {
    _caretTimer?.cancel();
    _caretTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _caretOn = !_caretOn);
    });
  }

  /// [widget.blocks]를 순서대로 훑으며 문장([TextBlock])은
  /// [_revealCharsPerTick]자씩 이어붙이고, 카드 등 다른 블록은 통째로
  /// [_visible]에 추가한다. 다 채우면 커서를 멈추고 [StreamingAiMessage.onRevealComplete]를
  /// 호출한다.
  Future<void> _reveal() async {
    for (final block in widget.blocks) {
      if (!mounted) return;
      if (block is TextBlock) {
        final text = block.text;
        var revealed = 0;
        setState(() => _visible.add(const TextBlock('')));
        widget.onRevealProgress?.call();
        while (revealed < text.length) {
          if (!mounted) return;
          revealed = (revealed + _revealCharsPerTick).clamp(0, text.length);
          setState(() => _visible[_visible.length - 1] =
              TextBlock(text.substring(0, revealed)));
          widget.onRevealProgress?.call();
          if (revealed < text.length) {
            await Future<void>.delayed(_revealTickDelay);
          }
        }
      } else {
        setState(() => _visible.add(block));
        widget.onRevealProgress?.call();
      }
      await Future<void>.delayed(_revealBlockGap);
    }
    if (!mounted) return;
    _caretTimer?.cancel();
    _caretTimer = null;
    setState(() {
      _revealed = true;
      _caretOn = false;
    });
    widget.onRevealProgress?.call();
    widget.onRevealComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final blocks = _visible;
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
            showCaret: !_revealed &&
                _caretOn &&
                i == blocks.length - 1 &&
                blocks[i] is TextBlock,
            onActionTap: widget.onActionTap,
          ),
        if (_revealed && widget.sources.isNotEmpty)
          _SourcesFooter(sources: widget.sources),
      ],
    );
  }
}

/// 응답 하단에 작게 보여주는 출처 목록(`ChatSourcesEvent`, 각 항목
/// `{name, note}`). 실 서버 응답의 `name`엔 이미 "출처: ⓒ..." 형태로
/// 안내 문구가 포함돼 있어(`docs/API_SPEC.md` 확인) 별도 헤더 없이 목록만
/// 나열한다.
class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter({required this.sources});

  final List<Map<String, dynamic>> sources;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [source['name'], source['note']]
                    .whereType<String>()
                    .where((text) => text.isNotEmpty)
                    .join(' '),
                style: AppTextStyles.body(fontSize: 11, color: colors.ink600),
              ),
            ),
        ],
      ),
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
