import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/widgets/app_icon.dart';

/// `attraction_detail_screen.dart`의 `_ImageCarousel`(사진 영역) 탭 시 여는
/// 확대 보기 화면에 넘기는 데이터. `context.pushNamed(RouteNames.photoViewer,
/// extra: ...)`로 전달한다(`WebViewRouteArgs`/`AttractionDetailArgs`와 동일한
/// extra 전달 패턴).
class PhotoViewerArgs {
  const PhotoViewerArgs({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;

  /// 탭한 사진부터 바로 보이도록 하는 시작 인덱스.
  final int initialIndex;
}

/// 사진을 검은 배경 위에 화면 가득 띄우고, 좌우로 넘기며(`PageView`) 각 장을
/// `InteractiveViewer`로 확대/축소·팬 할 수 있는 뷰어. 점 인디케이터는
/// `_ImageCarousel`과 같은 스타일을 재사용한다.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.args});

  final PhotoViewerArgs args;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.args.initialIndex);
  late int _page = widget.args.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final urls = widget.args.imageUrls;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: urls[index],
                    fit: BoxFit.contain,
                    // `CircularProgressIndicator`엔 기본 라벨이 없어 놓치고
                    // 있었다(VoiceOver 지원 재점검 중 발견).
                    placeholder: (_, __) => Semantics(
                      liveRegion: true,
                      label: l10n.photoViewerLoadingLabel,
                      child: const CircularProgressIndicator(),
                    ),
                    errorWidget: (_, __, ___) => AppIcon(
                      AppIconShape.image,
                      size: 32,
                      color: colors.ink600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: l10n.commonClose,
                onPressed: () => context.pop(),
                icon: AppIcon(AppIconShape.close,
                    color: colors.accentBright, size: 24),
              ),
            ),
            if (urls.length > 1)
              Positioned(
                bottom: 24,
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
      ),
    );
  }
}
