import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/api/api_client.dart';
import 'package:nullnull/api/attractions_api.dart';
import 'package:nullnull/app_log.dart';
import 'package:nullnull/app_router.dart';
import 'package:nullnull/data/map_launcher_service.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/screens/photo_viewer_screen.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/map_app_sheet.dart';
import 'package:nullnull/widgets/nullnull/alternatives_section.dart';
import 'package:nullnull/widgets/nullnull/congestion_badge.dart';
import 'package:nullnull/widgets/nullnull/crowd_bar_chart.dart';
import 'package:nullnull/widgets/nullnull/plain_header.dart';
import 'package:nullnull/widgets/skeleton_box.dart';

/// [AttractionDetailScreen]을 `context.pushNamed(RouteNames.attractionDetail,
/// extra: ...)`로 열 때 넘기는 인자. `web_view_screen.dart`의 `WebViewRouteArgs`와
/// 동일한 패턴. [initialTitle]은 목록 카드에서 이미 알고 있는 제목을 상세 조회가
/// 끝나기 전까지 헤더에 임시로 보여주기 위한 것(선택).
class AttractionDetailArgs {
  const AttractionDetailArgs({required this.contentId, this.initialTitle});

  final String contentId;
  final String? initialTitle;
}

/// 관광지 상세 화면. `docs/API_SPEC.md`의 `### attractions` 절 API 7개
/// (`{content_id}`/`crowd`/`images`/`alternatives`/`pet`/`similar`/`interest`)를
/// 조합해 구성한다. `{content_id}` 조회가 먼저 성공해야 나머지 6개를 호출한다
/// ("구현 주의": 404/503이면 하위 조회를 하지 않음).
class AttractionDetailScreen extends StatefulWidget {
  const AttractionDetailScreen({
    super.key,
    required this.contentId,
    this.initialTitle,
    this.attractionsApi,
  });

  final String contentId;
  final String? initialTitle;

  /// 테스트/향후 연동 전환을 위한 주입 지점(`chat_screen.dart`와 동일한 패턴).
  final AttractionsApi? attractionsApi;

  @override
  State<AttractionDetailScreen> createState() => _AttractionDetailScreenState();
}

class _AttractionDetailScreenState extends State<AttractionDetailScreen> {
  late final AttractionsApi _api = widget.attractionsApi ??
      LoggingAttractionsApi(DioAttractionsApi(ApiClient.create()));

  bool _loadingDetail = true;
  AttractionDetail? _detail;
  bool _detailNotFound = false;
  String? _detailErrorMessage;

  AttractionImages? _images;

  static const _crowdDayOptions = [7, 14, 28];
  int _crowdDays = _crowdDayOptions.first;
  bool _loadingCrowd = false;
  AttractionCrowdForecast? _crowd;
  bool _crowdFailed = false;

  AttractionAlternativesResult? _alternatives;
  AttractionPetInfo? _pet;
  List<SimilarAttraction>? _similar;
  AttractionInterestTrend? _interest;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
      _detailNotFound = false;
      _detailErrorMessage = null;
    });
    try {
      final detail = await _api.fetchDetail(contentId: widget.contentId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadingDetail = false;
      });
      // 상세 조회가 성공했을 때만 나머지 6개를 호출한다("구현 주의": 404/503이면
      // 여기까지 오지 않고 catch 블록에서 끝난다).
      unawaited(_loadImages());
      unawaited(_loadCrowd());
      unawaited(_loadAlternatives());
      unawaited(_loadPet());
      unawaited(_loadSimilar());
      unawaited(_loadInterest());
    } catch (e, stackTrace) {
      AppLog.logger.e('관광지 상세 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      final notFound =
          e is AttractionsApiException && e.isNotFoundOrUnavailable;
      setState(() {
        _loadingDetail = false;
        _detailNotFound = notFound;
        _detailErrorMessage =
            notFound ? null : (e is AttractionsApiException ? e.message : null);
      });
    }
  }

  /// 이미지/대안 여행지/반려동물/비슷한 관광지/검색 관심도는 상세 화면을 꾸미는
  /// 보조 정보라, 조회에 실패해도 에러 UI 없이 그 섹션만 조용히 숨긴다(로그만
  /// 남김) — 핵심 정보(상세/혼잡도)만 실패 시 눈에 보이는 안내를 준다.
  Future<void> _loadImages() async {
    try {
      final images = await _api.fetchImages(contentId: widget.contentId);
      if (!mounted) return;
      setState(() => _images = images);
    } catch (e, stackTrace) {
      AppLog.logger.w('관광지 이미지 조회 실패(섹션 숨김)', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadCrowd() async {
    setState(() {
      _loadingCrowd = true;
      _crowdFailed = false;
    });
    try {
      final forecast =
          await _api.fetchCrowd(contentId: widget.contentId, days: _crowdDays);
      if (!mounted) return;
      setState(() {
        _crowd = forecast;
        _loadingCrowd = false;
      });
    } catch (e, stackTrace) {
      AppLog.logger.e('혼잡도 예보 조회 실패', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loadingCrowd = false;
        _crowdFailed = true;
      });
    }
  }

  void _selectCrowdDays(int days) {
    if (days == _crowdDays) return;
    setState(() => _crowdDays = days);
    _loadCrowd();
  }

  Future<void> _loadAlternatives() async {
    try {
      final result =
          await _api.fetchAlternatives(contentId: widget.contentId, limit: 5);
      if (!mounted) return;
      setState(() => _alternatives = result);
    } catch (e, stackTrace) {
      AppLog.logger.w('대안 여행지 조회 실패(섹션 숨김)', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadPet() async {
    try {
      final pet = await _api.fetchPetInfo(contentId: widget.contentId);
      if (!mounted) return;
      setState(() => _pet = pet);
    } catch (e, stackTrace) {
      AppLog.logger
          .w('반려동물 동반 정보 조회 실패(섹션 숨김)', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadSimilar() async {
    try {
      final items =
          await _api.fetchSimilar(contentId: widget.contentId, limit: 5);
      if (!mounted) return;
      setState(() => _similar = items);
    } catch (e, stackTrace) {
      AppLog.logger.w('비슷한 관광지 조회 실패(섹션 숨김)', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadInterest() async {
    try {
      final trend = await _api.fetchInterest(contentId: widget.contentId);
      if (!mounted) return;
      setState(() => _interest = trend);
    } catch (e, stackTrace) {
      AppLog.logger.w('검색 관심도 조회 실패(섹션 숨김)', error: e, stackTrace: stackTrace);
    }
  }

  void _openAttraction(String contentId, String title) {
    context.pushNamed(
      RouteNames.attractionDetail,
      extra: AttractionDetailArgs(contentId: contentId, initialTitle: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Column(
          children: [
            PlainHeader(
              title: _detail?.summary.title ??
                  widget.initialTitle ??
                  l10n.attractionDetailTitle,
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailNotFound) {
      return _MessageState(message: l10n.attractionDetailNotFound);
    }
    if (_detail == null) {
      return _MessageState(
        message: _detailErrorMessage ?? l10n.attractionDetailLoadError,
        onRetry: _loadDetail,
      );
    }

    final colors = AppColors.of(context);
    final detail = _detail!;
    final summary = detail.summary;
    final imageUrls = [
      if (summary.image != null && summary.image!.isNotEmpty) summary.image!,
      ...(_images?.imageUrls ?? const <String>[]),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. 이미지 캐러셀
            _ImageCarousel(imageUrls: imageUrls),
            const SizedBox(height: 18),
            // 3. 장소이름, 상세 주소
            Text(summary.title,
                style: AppTextStyles.heading(fontSize: 26, color: colors.ink)),
            if (summary.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  AppIcon(AppIconShape.pin, color: colors.ink600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.address,
                      style: AppTextStyles.body(
                          fontSize: 13, color: colors.ink700),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _Divider(colors: colors),
            const SizedBox(height: 20),
            // 4. 혼잡도 그래프
            _SectionLabel(l10n.attractionDetailCrowdSection),
            _CrowdSection(
              days: _crowdDays,
              dayOptions: _crowdDayOptions,
              onSelectDays: _selectCrowdDays,
              loading: _loadingCrowd,
              failed: _crowdFailed,
              forecast: _crowd,
              onRetry: _loadCrowd,
            ),
            const SizedBox(height: 24),
            _Divider(colors: colors),
            const SizedBox(height: 20),
            // 5. 이용정보 + 지도에서 보기
            _SectionLabel(l10n.attractionDetailInfoSection),
            _InfoSection(
              info: detail.info,
              onOpenMap: () => MapAppSheet.show(
                context,
                placeName: summary.title,
                openKakaoMap: () => summary.mapX != null && summary.mapY != null
                    ? MapLauncherService.openKakaoMapAt(
                        summary.mapY!, summary.mapX!)
                    : MapLauncherService.openKakaoMap(summary.title),
                openNaverMap: () => summary.mapX != null && summary.mapY != null
                    ? MapLauncherService.openNaverMapAt(
                        summary.mapY!, summary.mapX!, summary.title)
                    : MapLauncherService.openNaverMap(summary.title),
              ),
            ),
            // 6. 상세 소개
            if (detail.overview != null && detail.overview!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Divider(colors: colors),
              const SizedBox(height: 20),
              _SectionLabel(l10n.attractionDetailIntroSection),
              Text(
                detail.overview!,
                style: AppTextStyles.body(color: colors.ink, height: 1.8),
              ),
            ],
            // 7. 함께 찾는 곳
            if (_alternatives != null && _alternatives!.items.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Divider(colors: colors),
              const SizedBox(height: 20),
              _SectionLabel(l10n.attractionDetailAlternativesSection),
              if (_alternatives!.base != null) ...[
                CongestionBadge(
                  level: _alternatives!.base!.level,
                  score: _alternatives!.base!.rate,
                ),
                const SizedBox(height: 10),
              ],
              AlternativesSection(
                items: _alternatives!.items,
                onTap: _openAttraction,
              ),
            ],
            // 8. 반려동물 정보
            if (_pet != null) ...[
              const SizedBox(height: 24),
              _Divider(colors: colors),
              const SizedBox(height: 20),
              _SectionLabel(l10n.attractionDetailPetSection),
              _PetSection(pet: _pet!),
            ],
            // 9. 유사도 데이터
            if (_similar != null && _similar!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Divider(colors: colors),
              const SizedBox(height: 20),
              _SectionLabel(l10n.attractionDetailSimilarSection),
              _SimilarSection(items: _similar!, onTap: _openAttraction),
            ],
            // 10. 검색 관심도
            if (_interest != null && _interest!.items.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Divider(colors: colors),
              const SizedBox(height: 20),
              _SectionLabel(l10n.attractionDetailInterestSection),
              _InterestSummary(items: _interest!.items),
            ],
            if (detail.source != null && detail.source!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                detail.source!,
                style: AppTextStyles.body(fontSize: 11, color: colors.ink600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 로딩 실패(또는 not-found) 상태를 보여주는 공용 뷰. [onRetry]가 있으면
/// 재시도 버튼을 함께 보여준다(`history_screen.dart`의 에러 상태와 같은 패턴).
class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: colors.ink600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.accent),
                ),
                child: Text(
                  l10n.historyRetryButton,
                  style: AppTextStyles.body(color: colors.accentBright),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: colors.divider);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTextStyles.body(
            fontSize: 16, color: colors.accentBright, letterSpacing: 1.8),
      ),
    );
  }
}

/// 2. 이미지 가로 슬라이드 캐러셀. `PageView` + 하단 점 인디케이터. 이미지가
/// 하나도 없으면 `_PlaceImage`(`place_detail_screen.dart`)와 동일하게
/// 스켈레톤 한 장만 보여준다.
class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final urls = widget.imageUrls;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration:
                  BoxDecoration(border: Border.all(color: colors.divider)),
              child: urls.isEmpty
                  ? SkeletonBox(
                      child: AppIcon(AppIconShape.image,
                          size: 22, color: colors.ink600),
                    )
                  : PageView.builder(
                      controller: _controller,
                      itemCount: urls.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => context.pushNamed(
                          RouteNames.photoViewer,
                          extra: PhotoViewerArgs(
                              imageUrls: urls, initialIndex: index),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: urls[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => SkeletonBox(
                            child: AppIcon(AppIconShape.image,
                                size: 22, color: colors.ink600),
                          ),
                          errorWidget: (_, __, ___) => SkeletonBox(
                            child: AppIcon(AppIconShape.image,
                                size: 22, color: colors.ink600),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (urls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < urls.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: i == _page ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? colors.accent
                            : colors.paper.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 4. 혼잡도 그래프 섹션 — 7/14/28일 선택 pill + 막대 그래프.
class _CrowdSection extends StatelessWidget {
  const _CrowdSection({
    required this.days,
    required this.dayOptions,
    required this.onSelectDays,
    required this.loading,
    required this.failed,
    required this.forecast,
    required this.onRetry,
  });

  final int days;
  final List<int> dayOptions;
  final ValueChanged<int> onSelectDays;
  final bool loading;
  final bool failed;
  final AttractionCrowdForecast? forecast;
  final VoidCallback onRetry;

  String _formatDate(DateTime? date) =>
      date == null ? '' : '${date.month}월 ${date.day}일';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final option in dayOptions) ...[
              _DayOptionPill(
                label: l10n.attractionDetailCrowdDaysOption(option),
                selected: option == days,
                onTap: () => onSelectDays(option),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (failed)
          _MessageState(
              message: l10n.attractionDetailLoadError, onRetry: onRetry)
        else if (forecast == null || forecast!.days.isEmpty)
          Text(l10n.chatCardNoDataMessage,
              style: AppTextStyles.body(color: colors.ink600))
        else ...[
          CrowdBarChart(days: forecast!.days),
          if (forecast!.summary != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.attractionDetailCrowdSummary(
                forecast!.summary!.avg,
                _formatDate(forecast!.summary!.peakDate),
                forecast!.summary!.peakRate,
                _formatDate(forecast!.summary!.minDate),
                forecast!.summary!.minRate,
              ),
              style: AppTextStyles.body(fontSize: 12.5, color: colors.ink600),
            ),
          ],
        ],
      ],
    );
  }
}

class _DayOptionPill extends StatelessWidget {
  const _DayOptionPill(
      {required this.label, required this.selected, required this.onTap});

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

/// 5. 이용정보(`data.info`의 키-값 목록, 서버 응답에 따라 항목이 달라 키를
/// 그대로 라벨로 쓴다) + 지도에서 보기 버튼. 원래 카카오맵/네이버지도 버튼 2개를
/// 나란히 뒀었는데(`_OutlineButton` 2개), 사용자 요청으로 [MapAppSheet]를 띄우는
/// 버튼 하나(`_MapButton`)로 통합했다.
class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.info, required this.onOpenMap});

  final List<AttractionInfoItem> info;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final entries = info.where((item) => item.value.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in entries) ...[
          Text(
            item.label,
            style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
          ),
          const SizedBox(height: 2),
          Text(
            item.value,
            style: AppTextStyles.body(
                fontSize: 14, color: colors.ink, height: 1.5),
          ),
          const SizedBox(height: 14),
        ],
        _MapButton(onTap: onOpenMap),
      ],
    );
  }
}

/// 카카오맵/네이버지도 버튼을 통합한 "지도에서 보기" 버튼(사용자 지정 시안:
/// `assets/images/map.svg` + 텍스트, `colors.accent`(#68BDF9) 1.5px 테두리,
/// `colors.paper`(#1C2023) 배경, 모서리 11, 높이 97, 너비 무한). 탭하면
/// [MapAppSheet]로 카카오맵/네이버지도 중 하나를 고르게 한다.
class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.paper,
          border: Border.all(color: colors.accent, width: 1.5),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/map.svg', height: 16,),
            const SizedBox(width: 10),
            Text(
              l10n.attractionDetailOpenMapButton,
              style: AppTextStyles.heading(fontSize: 15, color: colors.accent)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 7. 함께 찾는 곳 — 가로 스크롤 카드형 목록. [items] 순서는 서버가 이미
/// 혼잡도 우선으로 정렬해 보낸 것이라 **재정렬하지 않고 그대로** 그린다
/// (`docs/API_SPEC.md`의 "구현 주의").
/// 8. 반려동물 동반 정보. `status`가 `no_data`면(`AttractionPetInfo.hasData`가
/// `false`) 정보가 없다는 안내만, 있으면 원본 필드(`raw`)를 키-값으로 나열한다
/// (필드 스키마가 정해지지 않아 `_InfoSection`과 동일한 방식으로 처리).
class _PetSection extends StatelessWidget {
  const _PetSection({required this.pet});

  final AttractionPetInfo pet;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (!pet.hasData) {
      return Text(l10n.attractionDetailPetNoData,
          style: AppTextStyles.body(color: colors.ink600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in pet.items) ...[
          Text(item.label,
              style: AppTextStyles.body(fontSize: 12, color: colors.ink600)),
          const SizedBox(height: 2),
          Text(item.value,
              style: AppTextStyles.body(
                  fontSize: 14, color: colors.ink, height: 1.5)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// 9. 비슷한 관광지 — 세로 목록, 각 행에 유사도(%)를 보여준다.
class _SimilarSection extends StatelessWidget {
  const _SimilarSection({required this.items, required this.onTap});

  final List<SimilarAttraction> items;
  final void Function(String contentId, String title) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (final item in items) ...[
          InkWell(
            onTap: () => onTap(item.summary.contentId, item.summary.title),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.summary.title,
                        style: AppTextStyles.heading(
                            fontSize: 14, color: colors.ink),
                      ),
                      if (item.summary.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.summary.address,
                          style: AppTextStyles.body(
                              fontSize: 12, color: colors.ink600),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  l10n.attractionDetailSimilarityLabel(
                      (item.similarity.clamp(0, 1) * 100).round()),
                  style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// 10. 검색 관심도 — 시계열이 아니라 최근 [AttractionInterestItem.weeks]주간의
/// 방향성 요약(`trend`) + 증감률(`changePct`) 한 줄 요약이다(**실서버로
/// 확인함**, 애초 가정했던 막대 그래프용 시계열 데이터가 아니었음).
class _InterestSummary extends StatelessWidget {
  const _InterestSummary({required this.items});

  final List<AttractionInterestItem> items;

  (String, Color) _trendLabelAndColor(
      AppLocalizations l10n, AppColors colors, String trend) {
    return switch (trend) {
      'up' => (l10n.attractionDetailInterestTrendUp, colors.busyText),
      'down' => (l10n.attractionDetailInterestTrendDown, colors.quietText),
      _ => (l10n.attractionDetailInterestTrendFlat, colors.ink600),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          _buildRow(colors, l10n, item),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildRow(
      AppColors colors, AppLocalizations l10n, AttractionInterestItem item) {
    final (trendLabel, trendColor) =
        _trendLabelAndColor(l10n, colors, item.trend);
    final sign = item.changePct > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.displayName,
                style: AppTextStyles.heading(fontSize: 14, color: colors.ink),
              ),
            ),
            Text(trendLabel,
                style: AppTextStyles.body(fontSize: 12, color: trendColor)),
            const SizedBox(width: 6),
            Text(
              '$sign${item.changePct}%',
              style: AppTextStyles.tabularNums(
                  AppTextStyles.body(fontSize: 12, color: trendColor)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          l10n.attractionDetailInterestWeeksLabel(item.weeks),
          style: AppTextStyles.body(fontSize: 12, color: colors.ink600),
        ),
      ],
    );
  }
}
