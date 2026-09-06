import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/double_back_exit_mixin.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_drawer.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/chat/chat_input_bar.dart';
import 'package:nullnull/widgets/chat/message_actions_row.dart';
import 'package:nullnull/widgets/chat/streaming_ai_message.dart';
import 'package:nullnull/widgets/chat/user_message_bubble.dart';
import 'package:nullnull/widgets/fade_slide_in.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';
import 'package:nullnull/widgets/nullnull/theme_grid.dart';

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

class _ChatScreenState extends State<ChatScreen>
    with DoubleBackExitMixin<ChatScreen> {
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
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() {
      _entries.add(_UserChatEntry(_nextId++, text));
      _entries.add(_AiChatEntry(
          _nextId++, DemoScript.turnFor(_scriptIndex, languageCode)));
      _scriptIndex++;
    });
    unawaited(AnalyticsService.logChatMessageSent());
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBackPress();
      },
      child: Scaffold(
        backgroundColor: colors.paper,
        drawer: AppDrawer(onNewChat: _newChat),
        body: SafeArea(
          child: Column(
            children: [
              Builder(
                builder: (context) => AppHeader(
                  leading: IconButton(
                    icon:
                        AppIcon(AppIconShape.menu, size: 18, color: colors.ink),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    tooltip: l10n.chatHistoryTooltip,
                  ),
                  trailing: const Center(child: _ProfileAvatarButton()),
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
                        onActionTap: _send,
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

/// 헤더 우측 프로필 아바타 버튼. 탭하면 설정 화면으로 이동한다.
class _ProfileAvatarButton extends StatefulWidget {
  const _ProfileAvatarButton();

  @override
  State<_ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<_ProfileAvatarButton> {
  SnsProvider _provider = SnsProvider.kakao;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final provider = await LoginPreference.readLastProvider();
    if (!mounted || provider == null) return;
    setState(() => _provider = provider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final nickname = DemoUser.nicknameFor(_provider, languageCode);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => context.pushNamed(RouteNames.settings),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.accent),
        ),
        child: Text(
          nickname.substring(0, 1),
          style:
              AppTextStyles.heading(fontSize: 14, color: colors.accentBright),
        ),
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  SnsProvider _provider = SnsProvider.kakao;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    final provider = await LoginPreference.readLastProvider();
    if (!mounted || provider == null) return;
    setState(() => _provider = provider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final nickname = DemoUser.nicknameFor(_provider, languageCode);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.card,
                  ),
                  child: const Mascot(),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.chatGreeting(nickname),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                      fontSize: 15, color: colors.ink, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: ThemeGrid(onThemeTap: widget.onPromptTap),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
