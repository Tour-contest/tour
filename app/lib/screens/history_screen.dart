import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/chat_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/chat_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';

/// `history_screen.dart`의 전체/오늘 날짜 필터(사용자 요청). 서버에 대응하는
/// 파라미터가 없어 클라이언트에서 `ChatSessionSummary.lastActiveAt` 기준으로
/// 거른다.
enum _DateFilter { all, today }

/// 지난 대화 목록 화면. `docs/API_SPEC.md`의 `GET /api/v1/chat/sessions`(최근
/// 활동 순)를 [ChatApi.fetchSessions]로 호출해 보여준다. `docs/DESIGN.md`에는
/// 아직 이 화면의 레이아웃 스펙이 없어 다른 화면의 색상/타이포그래피
/// 컨벤션을 그대로 따라 구성했다. 항목을 탭하면
/// [ChatApi.fetchMessages]로 그 세션의 이력을 불러온 뒤 [ChatScreen]을
/// [ChatResumeData]와 함께 `goNamed`로 띄운다(`ChatScreen`이 뒤로가기 시 앱을
/// 종료하는 단일 홈 화면 전제라 `pushNamed`로 쌓지 않고 스택을 통째로
/// 교체함 — 로그인 성공 때와 동일한 방식).
///
/// 타이틀 검색 + 최신순 정렬(사용자 요청) — 먼저 `docs/API_SPEC.md`를 확인함:
/// `GET /api/v1/chat/sessions?limit=&offset=`는 애초에 "최근 활동 순"으로만
/// 내려오고 다른 정렬 옵션 자체가 없으며(그래서 고를 게 없어 별도 정렬
/// UI(드롭다운 등)는 만들지 않음, 대신 [_load]에서 `lastActiveAt` 내림차순으로
/// 한 번 더 클라이언트에서 방어적으로 정렬해 서버 응답 순서와 무관하게 항상
/// 최신순을 보장한다), 검색 파라미터(`q` 등)도 전혀 없다 — 즉 서버가 title
/// 검색을 지원하지 않는다. 그래서 [_searchController]로 **이미 불러온 목록
/// 안에서만** 클라이언트 쪽 필터링을 한다(서버 풀텍스트 검색이 아님). 이
/// 클라이언트 검색이 의미 있으려면 목록 자체가 너무 적으면 안 되므로,
/// 기존에 화면 안 UI로는 페이지네이션(`hasMore`)이 없어 사실상 최초 20개로
/// 잘려 있던 것을 [_fetchLimit](100)으로 넉넉히 늘렸다 — 다만 이것도 여전히
/// 유한한 개수라 "완전한 전체 이력 검색"은 아니며, 진짜 무한 스크롤/추가
/// 페이지 로드는 이번 범위를 넘는 별도 작업으로 남겨둔다.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.chatApi});

  /// 테스트/향후 실 연동 전환을 위한 주입 지점. 기본값은 [MockChatApi].
  final ChatApi? chatApi;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // `chat_screen.dart`와 동일하게 실 서버(`nullnull.kr`) 연동 상태를 유지한다.
  // 로그인 전이거나 액세스 토큰이 만료된 상태로 `GET /api/v1/chat/sessions`를
  // 호출하면 401이 오는데, 화면은 이를 그대로 에러 안내 + 재시도 버튼으로
  // 보여준다(`api_client.dart`의 `_AuthInterceptor`가 401을 가로채 자동으로
  // 토큰을 갱신한 뒤 재시도하므로, 로그인된 상태에서는 정상 조회됨).
  late final ChatApi _chatApi =
      widget.chatApi ?? LoggingChatApi(DioChatApi(ApiClient.create()));

  /// 서버에 페이지네이션(`offset`)을 이어붙여 부르는 UI(무한 스크롤 등)가
  /// 아직 없어, 기존 기본값(20)보다 넉넉히 올려 클라이언트 검색이 실제로
  /// 쓸모 있을 만큼 목록을 가져온다(클래스 문서 주석 참고).
  static const _fetchLimit = 100;

  List<ChatSessionSummary>? _sessions;
  bool _isLoading = true;
  bool _hasError = false;

  /// 세션 이력 조회(`_openSession`) 진행 중에는 화면 터치를 막고 로딩
  /// 인디케이터를 보여준다(`login_screen.dart`의 `_isLoggingIn`과 동일한
  /// `PopScope` + `Stack`/`ColoredBox` 패턴).
  bool _isOpeningSession = false;

  /// 타이틀 검색어(클라이언트 필터링 전용, 클래스 문서 주석 참고).
  final _searchController = TextEditingController();
  String _query = '';

  /// 전체/오늘 날짜 필터(사용자 요청, 검색과 마찬가지로 이미 불러온 목록
  /// 안에서만 거르는 클라이언트 필터링). 기본값은 전체.
  _DateFilter _dateFilter = _DateFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// `ChatScreen._send`와 같은 패턴(try/catch + setState)으로 [ChatApi]
  /// 호출을 처리한다. `FutureBuilder` 대신 이 방식을 쓰는 이유: 위젯 테스트
  /// 환경에서 `FutureBuilder`에 넘긴 Future가 (테스트용 mock처럼) 리스너가
  /// 붙기 전에 곧바로 실패하면 Dart의 미해결 Future 오류 감지가 오탐하는
  /// 사례가 있어, 에러를 항상 이 함수 안에서 직접 잡아 상태로 변환해둔다.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final page = await _chatApi.fetchSessions(limit: _fetchLimit);
      if (!mounted) return;
      // 서버가 이미 "최근 활동 순"으로 내려주지만(클래스 문서 주석 참고),
      // 클라이언트에서도 한 번 더 정렬해 항상 최신순임을 보장한다
      // (`lastActiveAt`이 없는 항목은 맨 뒤로).
      final sessions = [...page.sessions]..sort((a, b) {
          final aTime = a.lastActiveAt;
          final bTime = b.lastActiveAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLog.logger.e('지난 대화 목록 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// `ChatApi.fetchMessages`로 세션 이력을 불러와 [ChatScreen]을 이어보기
  /// 상태로 띄운다. 실패하면 [historyResumeError] 토스트만 안내한다.
  Future<void> _openSession(ChatSessionSummary session) async {
    if (_isOpeningSession) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isOpeningSession = true);
    try {
      final page = await _chatApi.fetchMessages(sessionId: session.sessionId);
      if (!mounted) return;
      context.goNamed(
        RouteNames.chat,
        extra: ChatResumeData(
            sessionId: session.sessionId, messages: page.messages),
      );
    } catch (e, stackTrace) {
      AppLog.logger.e('대화 이력 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isOpeningSession = false);
      AppToast.show(l10n.historyResumeError, type: AppToastType.info);
    }
  }

  /// `AppDrawer`의 "새 채팅" 버튼(`_newChat()`)과 동일한 결과(대화 비우고
  /// 세션 초기화)를 이 화면에서도 낸다. `ChatScreen`은 이미 `/chat` 스택에
  /// 살아있는 단일 홈 화면이라 `goNamed`로 스택을 다시 쌓지 않고 교체하며,
  /// `sessionId: null` + 빈 `messages`를 담은 [ChatResumeData]를 넘기면
  /// `_ChatScreenState.didUpdateWidget`이 이를 감지해 `_applyResume`으로
  /// 반영한다 — `_entries.clear()` + `_sessionId = null`이라 `_newChat()`과
  /// 완전히 동일한 결과(`## Architecture`의 `chat_screen.dart` 문단 참고).
  void _startNewChat() {
    context.goNamed(
      RouteNames.chat,
      // `const`를 쓰면 안 된다: 동일한 값의 `const ChatResumeData`는 Dart가
      // 같은 인스턴스로 정규화(canonicalize)해서, 이미 빈 대화 상태(`resume`이
      // 지난번과 같은 그 canonical 인스턴스)에서 이 버튼을 한 번 더 누르면
      // `_ChatScreenState.didUpdateWidget`의 `resume == oldWidget.resume`
      // 참조 비교가 true가 되어 아무 일도 안 일어난다 — 매번 새 인스턴스를
      // 만들어야 재진입해도 항상 감지된다.
      extra: ChatResumeData(sessionId: null, messages: const []),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_isOpeningSession,
      child: Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: Stack(
            children: [
              // 세션 이력 조회 중(`_isOpeningSession`)에는 화면 터치는 이미
              // 스크림으로 막혀 있지만, VoiceOver의 스와이프 탐색은 z-order와
              // 무관하게 시맨틱 트리를 그대로 훑기 때문에 목록의 모든
              // 항목(검색창 포함)이 계속 활성 상태로 잡혔다 — 조회 중에는
              // 이 콘텐츠 전체를 시맨틱 트리에서 제외한다(사용자 요청 —
              // VoiceOver 지원, 지난 대화 화면. `settings_screen.dart`의
              // `_isLoggingOut` 처리와 동일한 패턴).
              ExcludeSemantics(
                excluding: _isOpeningSession,
                child: Column(
                  children: [
                    PlainHeader(
                      title: l10n.historyTitle,
                      trailing: _DateFilterButton(
                        selected: _dateFilter,
                        onSelect: (filter) =>
                            setState(() => _dateFilter = filter),
                      ),
                    ),
                    // "새 채팅" 버튼은 목록 스크롤 영역(`Expanded`) 안에서만
                    // `Positioned`로 우하단에 띄운다(사용자 요청 — 일반적인
                    // `floatingActionButton`처럼 목록 위에 항상 떠 있고, 목록은
                    // 그 아래로 자유롭게 스크롤됨). `Expanded`의 경계가 곧
                    // 검색창 바로 위 지점이라, 좌표를 따로 계산하지 않아도
                    // 검색창과 겹치지 않는다.
                    Expanded(
                      child: Stack(
                        children: [
                          _buildBody(colors, l10n),
                          Positioned(
                            right: 20,
                            bottom: 16,
                            child: _NewChatButton(onTap: _startNewChat),
                          ),
                        ],
                      ),
                    ),
                    // 검색창은 목록과 함께 스크롤되지 않고 화면 하단에 고정한다
                    // (사용자 요청) — `Column`의 `Expanded` 형제로 둬서 목록만
                    // 스크롤 영역을 갖고 이 검색창은 항상 같은 자리에 남는다.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: _SearchField(controller: _searchController),
                    ),
                  ],
                ),
              ),
              if (_isOpeningSession)
                ColoredBox(
                  color: colors.scrim,
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.historyOpeningSessionLabel,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors, AppLocalizations l10n) {
    if (_isLoading) {
      // `CircularProgressIndicator`엔 기본 라벨이 없어(사용자 요청 —
      // VoiceOver 지원, 지난 대화 화면) 감싸는 `Semantics`로 announce한다.
      return Center(
        child: Semantics(
          liveRegion: true,
          label: l10n.historyLoadingLabel,
          child: CircularProgressIndicator(color: colors.accent),
        ),
      );
    }
    if (_hasError) {
      return _HistoryMessage(
        message: l10n.historyErrorMessage,
        actionLabel: l10n.historyRetryButton,
        onActionTap: _load,
      );
    }
    final sessions = _sessions!;
    if (sessions.isEmpty) {
      return _HistoryMessage(message: l10n.historyEmptyMessage);
    }
    // 전체/오늘 필터도 검색과 마찬가지로 서버 지원이 없어 이미 불러온
    // [sessions] 안에서만 `lastActiveAt`(기기 로컬 시각 기준)이 오늘 날짜인
    // 항목만 거른다.
    final now = DateTime.now();
    bool isToday(DateTime? time) =>
        time != null &&
        time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
    final dateFiltered = _dateFilter == _DateFilter.today
        ? sessions.where((s) => isToday(s.lastActiveAt)).toList()
        : sessions;
    // 검색 엔드포인트도 서버에 없어 title을 대소문자 구분 없이 부분일치로
    // 거른다(클래스 문서 주석 참고).
    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? dateFiltered
        : dateFiltered
            .where((s) => (s.title ?? '').toLowerCase().contains(query))
            .toList();
    if (filtered.isEmpty) {
      // 검색어가 있으면 검색 결과 없음 문구를 우선하고, 검색어 없이
      // "오늘" 필터만으로 비었으면 그 전용 문구를 보여준다.
      final message = query.isNotEmpty
          ? l10n.historySearchEmptyMessage
          : l10n.historyTodayEmptyMessage;
      return _HistoryMessage(message: message);
    }
    return ListView.separated(
      // 아래쪽만 넉넉히(카드 한 개 높이만큼, 사용자 요청) 더 줘서 맨 마지막
      // 카드까지 끝까지 스크롤했을 때 우하단에 떠 있는 `_NewChatButton`에
      // 가려지지 않게 한다(`Expanded(child: Stack([...]))`에서 이 목록과
      // 버튼이 같은 영역을 공유하는 구조라, 버튼을 투명 배리어로 피하는
      // 대신 목록 쪽에 여유 공간을 더 주는 방식을 택함).
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 84),
      itemCount: filtered.length,
      // 항목이 각자 테두리 있는 카드가 돼서(`_HistoryTile` 참고) 카드 사이에
      // 가로줄 구분선을 긋는 대신 여백만 준다 — 카드 2개가 붙어 선까지
      // 겹치면 시각적으로 어색해짐.
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _HistoryTile(
        session: filtered[index],
        onTap: () => _openSession(filtered[index]),
      ),
    );
  }
}

/// "새 채팅" 버튼. `app_drawer.dart`의 `_DrawerFooter`가 그리는 새 채팅
/// 버튼과 완전히 같은 UI(아이콘·텍스트·색상·모양)를 재사용한다(사용자 요청 —
/// 지난 대화 화면 우하단에도 같은 기능/모양의 버튼을 추가해달라고 함).
class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    // `InkWell`은 버튼 role이 없어 VoiceOver가 아이콘+텍스트를 각자 따로
    // 읽던 것을 하나로 묶는다(사용자 요청 — VoiceOver 지원, 지난 대화
    // 화면. `app_drawer.dart`의 같은 모양 버튼과 동일한 처리).
    return Semantics(
      button: true,
      label: l10n.chatNewTooltip,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.chatSendButton,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset('assets/images/plus.svg'),
                const SizedBox(width: 10),
                Text(l10n.chatNewTooltip,
                    style: AppTextStyles.body(
                            fontSize: 15, color: colors.ink, height: 1.6)
                        .copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 전체/오늘 날짜 필터 토글 버튼. 헤더 우측(`PlainHeader.trailing`)에 두고,
/// 탭하면 `chat_screen.dart`의 `_ProfileAvatarButton`과 같은 방식(
/// `CompositedTransformTarget`/`LayerLink` + `Overlay`)으로 바로 아래에
/// 팝업 메뉴를 띄운다(사용자 요청 — 기존 `_DateFilterChip` 2개짜리 가로
/// 토글을 이 버튼 + 팝업 메뉴로 대체함). 버튼 자체는 `app_header.dart`의
/// `_HeaderSlot`과 같은 구성(`assets/images/slot.png` 배경 + 아이콘)을
/// `assets/images/union.svg`(필터 깔때기 모양, 흰색 stroke라
/// `ColorFilter`로 톤을 맞춤)로 재현한다.
class _DateFilterButton extends StatefulWidget {
  const _DateFilterButton({required this.selected, required this.onSelect});

  final _DateFilter selected;
  final ValueChanged<_DateFilter> onSelect;

  @override
  State<_DateFilterButton> createState() => _DateFilterButtonState();
}

class _DateFilterButtonState extends State<_DateFilterButton> {
  // `app_header.dart`의 `_HeaderSlot` 탭 영역(44)과 맞춰 팝업이 실제 보이는
  // 슬롯 바로 아래에 붙도록 한다.
  static const double _slotSize = 44;

  final _menuLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuEntry != null) {
      _closeMenu();
      return;
    }
    final overlayState = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _DateFilterMenuOverlay(
        link: _menuLink,
        selected: widget.selected,
        onDismiss: _closeMenu,
        onSelect: (filter) {
          _closeMenu();
          widget.onSelect(filter);
        },
      ),
    );
    _menuEntry = entry;
    overlayState.insert(entry);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    // `GestureDetector`는 탭 액션은 자동으로 시맨틱 트리에 연결하지만 버튼
    // role이 없고, 별도 시각 툴팁도 없는 아이콘 전용 버튼이라 신규 l10n
    // 키(`historyDateFilterTooltip`)로 라벨을 준다 — `value`로 현재 선택된
    // 필터까지 함께 announce한다(사용자 요청 — VoiceOver 지원, 지난 대화
    // 화면).
    return Semantics(
      button: true,
      label: l10n.historyDateFilterTooltip,
      value: widget.selected == _DateFilter.today
          ? l10n.historyFilterToday
          : l10n.historyFilterAll,
      onTap: _toggleMenu,
      child: ExcludeSemantics(
        child: CompositedTransformTarget(
          link: _menuLink,
          child: GestureDetector(
            onTap: _toggleMenu,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: _slotSize,
              height: _slotSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset('assets/images/slot.png', width: 33, height: 33),
                  SvgPicture.asset(
                    'assets/images/union.svg',
                    width: 14,
                    colorFilter: ColorFilter.mode(colors.ink, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [_DateFilterButton] 탭 시 뜨는 팝업. `chat_screen.dart`의
/// `_ProfileMenuOverlay`와 동일한 구조(전체 화면 투명 배리어로 바깥 탭 감지 +
/// `CompositedTransformFollower`로 버튼 바로 아래에 카드 배치).
class _DateFilterMenuOverlay extends StatelessWidget {
  const _DateFilterMenuOverlay({
    required this.link,
    required this.selected,
    required this.onDismiss,
    required this.onSelect,
  });

  final LayerLink link;
  final _DateFilter selected;
  final VoidCallback onDismiss;
  final ValueChanged<_DateFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Positioned.fill(
          // 배리어 자체는 화면을 덮는 투명한 닫기 영역이라, VoiceOver가
          // 라벨 없는 빈 영역으로 announce하지 않도록 "닫기" 버튼으로
          // 명시한다(사용자 요청 — VoiceOver 지원, 지난 대화 화면.
          // `chat_screen.dart`의 `_ProfileMenuOverlay`와 동일한 처리).
          child: Semantics(
            button: true,
            label: l10n.commonClose,
            onTap: onDismiss,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
              ),
            ),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: _DateFilterMenuCard(
            selected: selected,
            onSelectAll: () => onSelect(_DateFilter.all),
            onSelectToday: () => onSelect(_DateFilter.today),
          ),
        ),
      ],
    );
  }
}

class _DateFilterMenuCard extends StatelessWidget {
  const _DateFilterMenuCard({
    required this.selected,
    required this.onSelectAll,
    required this.onSelectToday,
  });

  final _DateFilter selected;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectToday;

  static const double _width = 160;
  static const double _height = 90;

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 사용자 요청으로 "오늘"이 "전체"보다 위(순서상 먼저) 오도록
                  // 배치함. 기본 선택값은 여전히 `_DateFilter.all`
                  // (`_HistoryScreenState._dateFilter` 초기값 참고, 표시
                  // 순서와 기본값은 별개).
                  Expanded(
                    child: _DateFilterMenuItem(
                      label: l10n.historyFilterToday,
                      selected: selected == _DateFilter.today,
                      onTap: onSelectToday,
                      isFirst: true,
                    ),
                  ),
                  Expanded(
                    child: _DateFilterMenuItem(
                      label: l10n.historyFilterAll,
                      selected: selected == _DateFilter.all,
                      onTap: onSelectAll,
                    ),
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

class _DateFilterMenuItem extends StatelessWidget {
  const _DateFilterMenuItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isFirst = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `chat_screen.dart`의 `_ProfileMenuItem`/`settings_screen.dart`의
    // `_RadioRow`와 동일한 이유(`InkWell`은 버튼 role이 없음) — "오늘"/"전체"
    // 두 항목이 서로 배타적으로 선택되는 라디오 그룹이라 `selected`/
    // `inMutuallyExclusiveGroup`까지 함께 announce한다(사용자 요청 —
    // VoiceOver 지원, 지난 대화 화면).
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.centerLeft,
            margin: EdgeInsets.only(
                left: 8,
                right: 8,
                top: isFirst ? 8 : 0,
                bottom: isFirst ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: selected ? colors.dateFilterActiveBackground : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                textScaler: TextScaler.noScaling,
                style: AppTextStyles.body(fontSize: 15, color: colors.ink)
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

/// 지난 대화 타이틀 검색창. `chat_input_bar.dart`의 알약형 입력창과 같은
/// 테두리(`colors.inputBarBorder`) 스타일을 따르되, 배경은 사용자 지정대로
/// `colors.inputBar`를 20%(0x33/0xFF) 알파로 낮춘 반투명(#252A3133)을 쓴다.
/// 플레이스홀더 문구 대신 왼쪽에 `search.svg` 아이콘으로 검색창임을 표시한다
/// (사용자 요청). 입력값이 있으면 지우기(X) 버튼을 보여준다.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: colors.inputBar.withAlpha(0x33),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.inputBarBorder),
      ),
      child: Row(
        children: [
          // 플레이스홀더 텍스트 대신 아이콘만으로 검색창임을 표시하는
          // 디자인이라(사용자 지정 시안) VoiceOver에는 이 아이콘 대신 아래
          // `TextField`를 감싸는 `Semantics.label`로 목적을 알린다 —
          // 아이콘 자체는 순수 장식이라 제외한다(사용자 요청 — VoiceOver
          // 지원, 지난 대화 화면).
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/images/search.svg',
              width: 16,
              height: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: l10n.historySearchFieldLabel,
              child: TextField(
                controller: controller,
                style: AppTextStyles.body(fontSize: 15, color: colors.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              // `GestureDetector`만으로는 버튼 role이 없어 VoiceOver가 이
              // 아이콘을 그냥 빈 영역으로 announce하던 것을 고친다(사용자
              // 요청 — VoiceOver 지원, 지난 대화 화면).
              return Semantics(
                button: true,
                label: l10n.historySearchClearTooltip,
                onTap: controller.clear,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: controller.clear,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: AppIcon(AppIconShape.close,
                          size: 14, color: colors.ink600),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// `session.lastActiveAt` 기준 상대 시각 문구("n분전"/"n시간전"/"n일전",
/// 1분 미만은 "방금전")를 만든다(사용자 요청 — 기존 `MM.dd` 절대 날짜
/// 표기를 대체). 자정을 걸친 "오늘"/"어제" 같은 구분은 두지 않고 순수하게
/// 지금 시각과의 차이만 본다. `time`이 미래(기기 시계 오차 등)면 음수
/// `Duration`이 나와 아래 각 `in*` 비교를 전부 건너뛰므로 자연히 "방금전"으로
/// 처리된다.
String _formatRelativeTime(DateTime time, AppLocalizations l10n) {
  final diff = DateTime.now().difference(time);
  if (diff.inDays >= 1) return l10n.historyRelativeDays(diff.inDays);
  if (diff.inHours >= 1) return l10n.historyRelativeHours(diff.inHours);
  if (diff.inMinutes >= 1) return l10n.historyRelativeMinutes(diff.inMinutes);
  return l10n.historyRelativeJustNow;
}

/// 지난 대화 항목 카드(사용자 지정 시안 — 배경 `colors.graphite`(#292C36),
/// 테두리 `colors.inputBarBorder`(#4E5963) 1.5px, 모서리 반경 9, 안쪽 여백
/// horizontal 16 / vertical 12; 제목은 14px·줄높이 1.5·굵기 500·`colors.ink`
/// (#F2F6F9 — 지정된 `#fff`와 사실상 같은 "거의 흰색" 톤이라 앱 전역에서
/// 본문 텍스트에 이미 쓰는 이 토큰을 그대로 재사용, 새 순백색 토큰을 따로
/// 만들지 않음), 날짜는 13px·굵기 500·`colors.voiceListeningHint`(#737B87 —
/// 지정된 색과 정확히 일치하는 기존 토큰을 재사용)). 제목/날짜 배치를 기존
/// 가로 `Row`(제목 `Expanded` + 날짜)에서 세로 `Column`(제목 위, 날짜 아래)
/// 으로 바꿨다(사용자 요청).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session, required this.onTap});

  final ChatSessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final lastActiveAt = session.lastActiveAt;
    final title = session.title ?? l10n.historyUntitledSession;
    final relativeTime =
        lastActiveAt == null ? null : _formatRelativeTime(lastActiveAt, l10n);
    // `InkWell`만으로는 버튼 role이 없고, 제목/상대 시각이 각자 별도 `Text`라
    // 카드 하나를 다 들으려면 두 번 스와이프해야 했다 — 하나로 묶어
    // "제목, n분전"이 한 번에 읽히게 한다(사용자 요청 — VoiceOver 지원,
    // 지난 대화 화면. `app_drawer.dart`의 세션 미리보기 항목과 동일한
    // 패턴이나, 이 화면은 상대 시각까지 라벨에 포함함).
    return Semantics(
      button: true,
      label: relativeTime == null ? title : '$title, $relativeTime',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.graphite,
              border: Border.all(color: colors.inputBarBorder, width: 1.5),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                          fontSize: 14, height: 1.2, color: colors.ink)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                if (relativeTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    relativeTime,
                    style: AppTextStyles.body(
                            fontSize: 13, color: colors.voiceListeningHint)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 로딩 실패/빈 목록 안내. [actionLabel]/[onActionTap]을 함께 주면 재시도
/// 버튼도 보여준다(로딩 실패 케이스).
class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(fontSize: 14, color: colors.ink600),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onActionTap,
              child: Text(
                actionLabel!,
                style: AppTextStyles.body(
                    fontSize: 14, color: colors.accentBright),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
