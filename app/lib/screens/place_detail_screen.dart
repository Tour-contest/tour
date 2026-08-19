import 'package:flutter/material.dart';

import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/skeleton_box.dart';

/// TODO 제공 가능한 데이터로 추후 변경
/// 채팅 내 장소 추천 아이템(예: 강경 근대거리) 탭 시 이동하는 장소 상세 화면.
/// 지도/전화 SDK 연동 전 단계라 딥링크 버튼은 안내 스낵바만 띄우는 mock 동작.
class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key, required this.place});

  final PlaceRecommendation place;

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Column(
          children: [
            AppHeader(
              title: '장소 정보',
              leading: IconButton(
                icon: AppIcon(AppIconShape.chevronLeft,
                    size: 18, color: colors.ink),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '뒤로',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaceImage(imageUrl: place.imageUrl),
                    const SizedBox(height: 18),
                    Text(
                      place.name,
                      style: AppTextStyles.heading(
                          fontSize: 26, color: colors.ink),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AppIcon(AppIconShape.pin,
                            size: 13, color: colors.ink600),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            place.location,
                            style: AppTextStyles.body(
                                fontSize: 13, color: colors.ink700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.gold),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '혼잡도 ${place.congestionPercent}%',
                            style: AppTextStyles.tabularNums(
                              AppTextStyles.body(
                                  fontSize: 10.5, color: colors.gold700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Divider(colors: colors),
                    const SizedBox(height: 20),
                    _SectionLabel('장소 소개'),
                    Text(
                      place.introduction,
                      style: AppTextStyles.body(color: colors.ink, height: 1.8),
                    ),
                    const SizedBox(height: 24),
                    _Divider(colors: colors),
                    const SizedBox(height: 20),
                    _SectionLabel('위치'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(AppIconShape.pin,
                            size: 14, color: colors.gold700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            place.address,
                            style: AppTextStyles.body(
                                fontSize: 14, color: colors.ink, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _OutlineButton(
                          label: '지도 앱에서 보기',
                          icon: AppIconShape.arrowUpRight,
                          onTap: () =>
                              _showComingSoon(context, '지도 앱 연동은 준비 중이에요.'),
                        ),
                        const SizedBox(width: 10),
                        _OutlineButton(
                          label: '네이버 지도로 열기',
                          icon: AppIconShape.arrowUpRight,
                          onTap: () =>
                              _showComingSoon(context, '네이버 지도 연동은 준비 중이에요.'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Divider(colors: colors),
                    const SizedBox(height: 20),
                    _SectionLabel('전화번호'),
                    Row(
                      children: [
                        AppIcon(AppIconShape.phone,
                            size: 14, color: colors.gold700),
                        const SizedBox(width: 8),
                        Text(
                          place.phone,
                          style: AppTextStyles.tabularNums(
                            AppTextStyles.body(fontSize: 14, color: colors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _OutlineButton(
                      label: '전화 걸기',
                      expand: true,
                      onTap: () => _showComingSoon(context, '전화 연결은 준비 중이에요.'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 장소 상세 이미지 영역. `imageUrl`이 없거나 로딩 전/실패 시에는
/// [SkeletonBox]로 대체된다(현재 데모 데이터는 실제 이미지가 없어 항상 표시됨).
class _PlaceImage extends StatelessWidget {
  const _PlaceImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        child: imageUrl == null
            ? SkeletonBox(
                child:
                    AppIcon(AppIconShape.image, size: 22, color: colors.ink600),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SkeletonBox(
                    child: AppIcon(AppIconShape.image,
                        size: 22, color: colors.ink600),
                  );
                },
                errorBuilder: (context, error, stackTrace) => SkeletonBox(
                  child: AppIcon(AppIconShape.image,
                      size: 22, color: colors.ink600),
                ),
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
            fontSize: 11, color: colors.gold700, letterSpacing: 1.8),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final AppIconShape? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final button = InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.gold),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.body(
                  fontSize: 13, color: colors.gold700, letterSpacing: .3),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              AppIcon(icon!, size: 12, color: colors.gold700),
            ],
          ],
        ),
      ),
    );
    return expand
        ? SizedBox(width: double.infinity, child: button)
        : Expanded(child: button);
  }
}
