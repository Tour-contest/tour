import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
/// 아직 이 화면의 레이아웃 스펙이 없어 `place_detail_screen.dart`와 같은 다른
/// 화면의 색상/타이포그래피 컨벤션을 그대로 따라 구성했다. 항목을 탭하면
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
              Column(
                children: [
                  PlainHeader(title: l10n.historyTitle),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: _SearchField(
                      controller: _searchController,
                      hintText: l10n.historySearchHint,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Row(
                      children: [
                        _DateFilterChip(
                          label: l10n.historyFilterAll,
                          selected: _dateFilter == _DateFilter.all,
                          onTap: () =>
                              setState(() => _dateFilter = _DateFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _DateFilterChip(
                          label: l10n.historyFilterToday,
                          selected: _dateFilter == _DateFilter.today,
                          onTap: () =>
                              setState(() => _dateFilter = _DateFilter.today),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildBody(colors, l10n)),
                ],
              ),
              if (_isOpeningSession)
                ColoredBox(
                  color: colors.scrim,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors, AppLocalizations l10n) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Container(height: 1, color: colors.divider),
      itemBuilder: (context, index) => _HistoryTile(
        session: filtered[index],
        onTap: () => _openSession(filtered[index]),
      ),
    );
  }
}

/// 전체/오늘 필터 선택 칩. `attraction_detail_screen.dart`의 `_DayOptionPill`
/// (7/14/28일 선택)과 같은 시각 스타일을 따른다.
class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint14 : colors.surfaceMuted,
          border: Border.all(
              color: selected ? colors.accent : colors.surfaceMutedBorder),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 12.5,
            color: selected ? colors.accentBright : colors.ink600,
          ),
        ),
      ),
    );
  }
}

/// 지난 대화 타이틀 검색창. `chat_input_bar.dart`의 알약형 입력창과 같은
/// 스타일(`colors.inputBar` 배경 + `colors.inputBarBorder` 테두리)을 따른다.
/// 입력값이 있으면 지우기(X) 버튼을 보여준다.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.inputBar,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.inputBarBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.body(fontSize: 15, color: colors.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle:
                    AppTextStyles.body(fontSize: 15, color: colors.ink600),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: controller.clear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: AppIcon(AppIconShape.close,
                      size: 14, color: colors.ink600),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session, required this.onTap});

  final ChatSessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final lastActiveAt = session.lastActiveAt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.title ?? l10n.historyUntitledSession,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(fontSize: 16, color: colors.ink),
              ),
            ),
            if (lastActiveAt != null) ...[
              const SizedBox(width: 10),
              Text(
                DateFormat('MM.dd').format(lastActiveAt),
                style: AppTextStyles.body(fontSize: 13, color: colors.ink600),
              ),
            ],
          ],
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
