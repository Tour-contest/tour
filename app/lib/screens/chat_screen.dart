import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/chat_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/analytics_service.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/demo_user.dart';
import 'package:nullnull/data/login_preference.dart';
import 'package:nullnull/data/logout_service.dart';
import 'package:nullnull/data/user_profile_storage.dart';
import 'package:nullnull/double_back_exit_mixin.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_drawer.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/confirm_dialog.dart';
import 'package:nullnull/widgets/push_drawer.dart';
import 'package:nullnull/widgets/chat/chat_input_bar.dart';
import 'package:nullnull/widgets/chat/message_actions_row.dart';
import 'package:nullnull/widgets/chat/streaming_ai_message.dart';
import 'package:nullnull/widgets/chat/user_message_bubble.dart';
import 'package:nullnull/widgets/fade_slide_in.dart';
import 'package:nullnull/widgets/nullnull/mascot.dart';
import 'package:nullnull/widgets/nullnull/profile_avatar.dart';
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
  _AiChatEntry(super.id);

  /// [ChatApi.sendMessage]의 SSE 이벤트가 도착하는 대로 실시간으로 자라는
  /// 블록 목록(`_send`가 매 이벤트마다 `setState`로 채워 넣는다). 비어 있으면
  /// 아직 첫 이벤트도 못 받은 상태(생각 중 표시).
  final List<AiBlock> blocks = [];

  /// 스트림이 끝까지(성공적으로) 도착했는지. `false`인 동안 커서가 깜빡인다.
  bool done = false;
}

/// docs/DESIGN.md 화면 2·3: 채팅(빈 상태 / 대화).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.chatApi});

  /// 테스트/향후 실 연동 전환을 위한 주입 지점(`history_screen.dart`와 동일한
  /// 패턴). 기본값은 실 서버(`nullnull.kr`) 연동.
  final ChatApi? chatApi;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with DoubleBackExitMixin<ChatScreen> {
  final List<_ChatEntry> _entries = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _drawerKey = GlobalKey<PushDrawerState>();
  final _appDrawerKey = GlobalKey<AppDrawerState>();
  // `nullnull.kr`(docs/API_SPEC.md `POST /api/v1/chat/stream`)에 실제로 붙는다.
  // 로그인 후에는 `ApiClient.create()`가 붙이는 `Authorization` 헤더로 인증까지
  // 됨을 확인함(로그인 전이거나 토큰 만료 시에는 401, `_send`가 실패 토스트만 띄움).
  late final ChatApi _chatApi =
      widget.chatApi ?? LoggingChatApi(DioChatApi(ApiClient.create()));
  String? _sessionId;
  int _nextId = 0;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// `docs/API_SPEC.md`의 `POST /api/v1/chat/stream`을 [ChatApi.sendMessage]로
  /// 호출해 SSE 이벤트를 순서대로 소비한다. 문장을 다 받은 뒤 한 번에 넘기는 대신,
  /// [ChatDeltaEvent]/[ChatCardEvent]가 올 때마다 [_AiChatEntry.blocks]를 그
  /// 자리에서 늘려 `setState`하므로 화면에는 실제로 서버가 보낸 텍스트가 도착하는
  /// 속도 그대로 나타난다(더 이상 다 받고 나서 타이핑을 흉내 내지 않음). 카드가
  /// 문장보다 먼저 도착할 수 있으므로 도착 순서 그대로 쌓는다. 실패해도 **자동
  /// 재시도하지 않는다** — 사용자가 다시 입력해야 재요청된다.
  void _send(String text) async {
    final userEntryId = _nextId++;
    final aiEntryId = _nextId++;
    final aiEntry = _AiChatEntry(aiEntryId);
    setState(() {
      _entries.add(_UserChatEntry(userEntryId, text));
      _entries.add(aiEntry);
    });
    unawaited(AnalyticsService.logChatMessageSent());
    _scrollToBottomSoon();

    void appendDelta(String chunk) {
      final blocks = aiEntry.blocks;
      final last = blocks.isEmpty ? null : blocks.last;
      if (last is TextBlock) {
        blocks[blocks.length - 1] = TextBlock('${last.text}$chunk');
      } else {
        blocks.add(TextBlock(chunk));
      }
    }

    try {
      await for (final event in _chatApi.sendMessage(
        text: text,
        sessionId: _sessionId,
      )) {
        switch (event) {
          case ChatMetaEvent(:final sessionId):
            _sessionId = sessionId;
          case ChatDeltaEvent(text: final chunk):
            if (!mounted) return;
            setState(() => appendDelta(chunk));
            _scrollToBottomSoon();
          case ChatCardEvent(:final type, :final payload):
            final block =
                event.demoBlock ?? ChatCardBlock(type: type, payload: payload);
            if (!mounted) return;
            setState(() => aiEntry.blocks.add(block));
            _scrollToBottomSoon();
          case ChatErrorEvent(:final message):
            throw ChatApiException(message);
          case ChatFinalEvent():
          case ChatStatusEvent():
          case ChatToolEvent():
          case ChatSourcesEvent():
          case ChatDoneEvent():
          case ChatUnknownEvent():
            break;
        }
      }
    } catch (e, stackTrace) {
      AppLog.logger.e('채팅 메시지 전송 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _entries.removeWhere((entry) => entry.id == aiEntryId));
      AppToast.show(
        AppLocalizations.of(context)!.chatSendFailedToast,
        type: AppToastType.info,
      );
      return;
    }

    if (!mounted) return;
    setState(() => aiEntry.done = true);
    _scrollToBottomSoon();
  }

  void _regenerate(_AiChatEntry entry) {
    final index = _entries.indexOf(entry);
    if (index == -1 || entry.blocks.isEmpty) return;
    final newEntry = _AiChatEntry(_nextId++)
      ..blocks.addAll(entry.blocks)
      ..done = true;
    setState(() => _entries[index] = newEntry);
  }

  void _newChat() {
    setState(() {
      _entries.clear();
      _sessionId = null;
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
        key: _appDrawerKey,
        chatApi: _chatApi,
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
                  onLeadingTap: () {
                    _appDrawerKey.currentState?.refresh();
                    _drawerKey.currentState?.open();
                  },
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
              _AiChatEntry() when entry.blocks.isEmpty =>
                const _ThinkingIndicator(),
              _AiChatEntry() => ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamingAiMessage(
                        key: ValueKey('stream-${entry.id}'),
                        blocks: entry.blocks,
                        streaming: !entry.done,
                        onActionTap: _send,
                      ),
                      if (entry.done)
                        MessageActionsRow(
                          textToCopy:
                              StreamingAiMessage.plainText(entry.blocks),
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

/// [ChatApi.sendMessage] 스트림의 첫 이벤트를 기다리는 동안 보여주는 안내.
/// `StreamingAiMessage`의 "널널" 라벨 행과 같은 스타일(골드 점 + 라벨)을 쓴다.
class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> {
  bool _dotOn = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _dotOn = !_dotOn);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _dotOn ? 1 : 0.2,
          child: Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(color: colors.accent, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          l10n.chatThinkingLabel,
          style: AppTextStyles.body(fontSize: 13, color: colors.ink),
        ),
      ],
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

  // 카카오 로그인 성공 시 저장해둔 실제 닉네임/프로필 사진(`login_screen.dart`의
  // `_saveKakaoProfile`). 없으면(네이버 mock 로그인, 동의 안 함 등) 기존처럼
  // `DemoUser` 목업 닉네임의 첫 글자로 대체한다(`settings_screen.dart`의
  // `_ProfileSummary`와 동일한 패턴).
  UserProfile? _profile;

  final _menuLink = LayerLink();
  OverlayEntry? _menuEntry;

  /// 로그아웃 요청(`LogoutService.logout`) 진행 중 화면 전체를 덮어 터치를
  /// 막고 로딩 인디케이터를 보여주는 별도 오버레이(`settings_screen.dart`의
  /// `_isLoggingOut` + `Stack`/`ColoredBox`와 같은 목적이지만, 이 위젯은 전체
  /// 화면 `Scaffold`를 갖고 있지 않아 같은 `OverlayEntry` 메커니즘(`_menuEntry`
  /// 참고)으로 구현한다).
  OverlayEntry? _loadingEntry;

  @override
  void initState() {
    super.initState();
    _loadProvider();
    _loadProfile();
  }

  @override
  void dispose() {
    _closeMenu();
    _hideLoadingOverlay();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    final provider = await LoginPreference.readLastProvider();
    if (!mounted || provider == null) return;
    setState(() => _provider = provider);
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileStorage.read();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
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

  void _showLoadingOverlay() {
    final overlayState = Overlay.of(context);
    final entry =
        OverlayEntry(builder: (_) => const _FullScreenLoadingOverlay());
    _loadingEntry = entry;
    overlayState.insert(entry);
  }

  void _hideLoadingOverlay() {
    _loadingEntry?.remove();
    _loadingEntry = null;
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
    _showLoadingOverlay();
    await LogoutService.logout(_provider);
    _hideLoadingOverlay();
    if (!mounted) return;
    context.goNamed(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final nickname =
        _profile?.nickname ?? DemoUser.nicknameFor(_provider, languageCode);
    return CompositedTransformTarget(
      link: _menuLink,
      child: GestureDetector(
        onTap: _toggleMenu,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _slotSize,
          height: _slotSize,
          child: ProfileAvatar(
            size: _slotSize,
            imageUrl: _profile?.profileImageUrl,
            initial: nickname.substring(0, 1),
            initialStyle: AppTextStyles.heading(
                fontSize: 18, color: colors.ink, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// 로그아웃 진행 중 화면 전체를 덮는 로딩 오버레이. `login_screen.dart`의
/// `_isLoggingIn` 오버레이(`ColoredBox` + `CircularProgressIndicator`)와 같은
/// 모양이지만, 여기는 `Scaffold` 하나가 아니라 전역 `Overlay`에 직접 얹는
/// 형태라 `Positioned.fill`로 화면 전체를 채운다.
class _FullScreenLoadingOverlay extends StatelessWidget {
  const _FullScreenLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: colors.scrim,
        child: const Center(child: CircularProgressIndicator()),
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
