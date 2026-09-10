import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/data/logout_service.dart';
import 'package:nullnull/double_back_exit_mixin.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_drawer.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/confirm_dialog.dart';
import 'package:nullnull/widgets/push_drawer.dart';
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
  final _drawerKey = GlobalKey<PushDrawerState>();
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
    return PushDrawer(
      key: _drawerKey,
      drawer: AppDrawer(
        onNewChat: _newChat,
        onClose: () => _drawerKey.currentState?.close(),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final drawer = _drawerKey.currentState;
          if (drawer != null && drawer.isOpen) {
            drawer.close();
            return;
          }
          handleBackPress();
        },
        child: Scaffold(
          backgroundColor: colors.loginBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader(
                  backgroundColor: colors.loginBackground,
                  leading: SvgPicture.asset('assets/images/icon_menu.svg'),
                  onLeadingTap: () => _drawerKey.currentState?.open(),
                  leadingTooltip: l10n.chatHistoryTooltip,
                  trailing: const Center(child: _ProfileAvatarButton()),
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

/// 헤더 우측 프로필 아바타. 탭하면 아이콘 바로 아래에 "설정"/"로그아웃" 2개
/// 메뉴가 담긴 팝업(`popup_slot.png` 배경)을 띄운다. `AppHeader`에 더 이상
/// `onTrailingTap`을 넘기지 않고, 이 위젯이 직접 제스처와 팝업을 관리한다.
class _ProfileAvatarButton extends StatefulWidget {
  const _ProfileAvatarButton();

  @override
  State<_ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<_ProfileAvatarButton> {
  // `AppHeader`의 `_HeaderSlot`이 아이콘 슬롯에 쓰는 탭 영역 크기(44)와 맞춰
  // 팝업이 실제 보이는 아이콘 바로 아래에 붙도록 한다.
  static const double _slotSize = 44;

  SnsProvider _provider = SnsProvider.kakao;
  final _menuLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    final provider = await LoginPreference.readLastProvider();
    if (!mounted || provider == null) return;
    setState(() => _provider = provider);
  }

  void _toggleMenu() {
    if (_menuEntry != null) {
      _closeMenu();
      return;
    }
    final overlayState = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _ProfileMenuOverlay(
        link: _menuLink,
        onDismiss: _closeMenu,
        onSettingsTap: _openSettings,
        onLogoutTap: _confirmLogout,
      ),
    );
    _menuEntry = entry;
    overlayState.insert(entry);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _openSettings() {
    _closeMenu();
    context.pushNamed(RouteNames.settings);
  }

  Future<void> _confirmLogout() async {
    _closeMenu();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: l10n.settingsLogoutDialogTitle,
        message: l10n.settingsLogoutDialogMessage,
        confirmLabel: l10n.settingsLogout,
      ),
    );
    if (confirmed != true || !mounted) return;
    await LogoutService.logout(_provider);
    if (!mounted) return;
    context.goNamed(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final nickname = DemoUser.nicknameFor(_provider, languageCode);
    return CompositedTransformTarget(
      link: _menuLink,
      child: GestureDetector(
        onTap: _toggleMenu,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _slotSize,
          height: _slotSize,
          child: Center(
            child: Text(
              nickname.substring(0, 1),
              style: AppTextStyles.heading(
                  fontSize: 18, color: colors.ink, weight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// [_ProfileAvatarButton] 탭 시 뜨는 팝업. 화면 전체를 덮는 투명 배리어로
/// 바깥 탭을 감지해 닫고, `CompositedTransformFollower`로 아바타 바로 아래에
/// 메뉴 카드를 붙인다.
class _ProfileMenuOverlay extends StatelessWidget {
  const _ProfileMenuOverlay({
    required this.link,
    required this.onDismiss,
    required this.onSettingsTap,
    required this.onLogoutTap,
  });

  final LayerLink link;
  final VoidCallback onDismiss;
  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: _ProfileMenuCard(
            onSettingsTap: onSettingsTap,
            onLogoutTap: onLogoutTap,
          ),
        ),
      ],
    );
  }
}

/// `popup_slot.png`(2:1 비율, 다른 `*_slot.png` 배경과 같은 2배율 원칙 적용)를
/// 154×77 크기로 깔고 그 위에 "설정"/"로그아웃" 2행을 올린 메뉴 카드.
class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.onSettingsTap,
    required this.onLogoutTap,
  });

  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  static const double _width = 154;
  static const double _height = 77;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _width,
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/popup_slot.png', fit: BoxFit.fill),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProfileMenuItem(
                    label: l10n.commonSettings,
                    onTap: onSettingsTap,
                    isFirst: true,
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuItem(
                    label: l10n.settingsLogout,
                    onTap: onLogoutTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.label,
    required this.onTap,
    this.isFirst = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(label,
            style: AppTextStyles.body(fontSize: 15, color: colors.ink)
                .copyWith(fontWeight: FontWeight.w500)),
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          border: Border.all(
                              color: colors.inputBarBorder, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accent.withAlpha(56),
                              blurRadius: 44,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Mascot(size: 70),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.chatGreeting(nickname),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading(
                          fontSize: 18,
                          color: colors.ink,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ThemeGrid(onThemeTap: widget.onPromptTap),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
