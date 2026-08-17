import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/chat/chat_input_bar.dart';
import 'package:nullnull/widgets/chat/message_actions_row.dart';
import 'package:nullnull/widgets/chat/streaming_ai_message.dart';
import 'package:nullnull/widgets/chat/suggested_prompt_row.dart';
import 'package:nullnull/widgets/chat/user_message_bubble.dart';
import 'package:nullnull/screens/history_screen.dart';
import 'package:nullnull/widgets/fade_slide_in.dart';

sealed class _ChatEntry {
  const _ChatEntry(this.id);
  final int id;
}

class _UserChatEntry extends _ChatEntry {
  const _UserChatEntry(super.id, this.text);
  final String text;
}

class _AiChatEntry extends _ChatEntry {
  _AiChatEntry(super.id, this.turn);
  final AiTurn turn;
  bool completed = false;
}

/// docs/DESIGN.md 화면 2·3: 채팅(빈 상태 / 대화).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatEntry> _entries = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  int _scriptIndex = 0;
  int _nextId = 0;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    setState(() {
      _entries.add(_UserChatEntry(_nextId++, text));
      _entries.add(_AiChatEntry(_nextId++, DemoScript.turnFor(_scriptIndex)));
      _scriptIndex++;
    });
    _scrollToBottomSoon();
  }

  void _regenerate(_AiChatEntry entry) {
    final index = _entries.indexOf(entry);
    if (index == -1) return;
    setState(() {
      _entries[index] = _AiChatEntry(_nextId++, entry.turn);
    });
  }

  void _newChat() {
    setState(() {
      _entries.clear();
      _scriptIndex = 0;
    });
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _openHistory() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: '널널',
              subtitle: '한적한 여행을 위한 비서',
              leading: IconButton(
                icon: AppIcon(AppIconShape.menu, size: 18, color: colors.ink),
                onPressed: _openHistory,
                tooltip: '지난 대화',
              ),
              trailing: IconButton(
                icon:
                    AppIcon(AppIconShape.refresh, size: 18, color: colors.ink),
                onPressed: _newChat,
                tooltip: '새 대화',
              ),
            ),
            Expanded(
              child: _entries.isEmpty
                  ? _EmptyState(onPromptTap: _send)
                  : _buildThread(),
            ),
            ChatInputBar(controller: _inputController, onSend: _send),
          ],
        ),
      ),
    );
  }

  Widget _buildThread() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Padding(
          key: ValueKey(entry.id),
          padding: const EdgeInsets.only(bottom: 20),
          child: FadeSlideIn(
            child: switch (entry) {
              _UserChatEntry(:final text) => UserMessageBubble(text: text),
              _AiChatEntry() => ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamingAiMessage(
                        key: ValueKey('stream-${entry.id}'),
                        turn: entry.turn,
                        onComplete: () {
                          if (!mounted) return;
                          setState(() => entry.completed = true);
                          _scrollToBottomSoon();
                        },
                      ),
                      if (entry.completed)
                        MessageActionsRow(
                          textToCopy: StreamingAiMessage.plainText(entry.turn),
                          onRegenerate: () => _regenerate(entry),
                        ),
                    ],
                  ),
                ),
            },
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 여행,\n조금 더 널널하게 가볼까요?',
            style: AppTextStyles.display(fontSize: 28, color: colors.ink)
                .copyWith(height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            '궁금한 여행지나 지금 이 순간의 혼잡도를 물어보세요',
            style: AppTextStyles.body(
                fontSize: 14, color: colors.ink700, height: 1.6),
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < DemoScript.suggestedPrompts.length; i++)
            SuggestedPromptRow(
              text: DemoScript.suggestedPrompts[i],
              isLast: i == DemoScript.suggestedPrompts.length - 1,
              onTap: () => onPromptTap(DemoScript.suggestedPrompts[i]),
            ),
        ],
      ),
    );
  }
}
