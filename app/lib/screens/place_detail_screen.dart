import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nullnull/app_log.dart';
import 'package:nullnull/data/demo_script.dart';
import 'package:nullnull/data/map_launcher_service.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_header.dart';
import 'package:nullnull/widgets/app_icon.dart';
import 'package:nullnull/widgets/app_toast.dart';
import 'package:nullnull/widgets/skeleton_box.dart';

/// TODO 제공 가능한 데이터로 추후 변경
/// 채팅 내 장소 추천 아이템(예: 강경 근대거리) 탭 시 이동하는 장소 상세 화면.
class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key, required this.place});

  final PlaceRecommendation place;

  /// [MapAppSheet]와 동일하게 좌표가 없어 장소명으로 검색하는 스킴을 쓴다.
  /// 앱 미설치 시 [MapLauncherService]가 스토어로 대신 이동시키고, 그마저
  /// 실패하면 `map_app_sheet.dart`와 같은 안내 문구를 띄운다.
  Future<void> _openMap(
      BuildContext context, Future<bool> Function() launch) async {
    final unavailableMessage =
        AppLocalizations.of(context)!.mapAppSheetUnavailable;
    final opened = await launch();
    if (opened) return;
    AppToast.show(unavailableMessage, type: AppToastType.info);
  }

  Future<void> _call(BuildContext context) async {
    final unavailableMessage =
        AppLocalizations.of(context)!.placeDetailCallUnavailable;
    final uri = Uri(scheme: 'tel', path: place.phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (error) {
      AppLog.logger.e('전화 앱 실행 실패: $uri', error: error);
    }
    AppToast.show(unavailableMessage, type: AppToastType.info);
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
            AppHeader(
              title: l10n.placeDetailTitle,
              leading: IconButton(
                icon: AppIcon(AppIconShape.chevronLeft,
                    size: 18, color: colors.ink),
                onPressed: () => context.pop(),
                tooltip: l10n.commonBack,
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
                            border: Border.all(color: colors.accent),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            l10n.chatCongestionLabel(place.congestionPercent),
                            style: AppTextStyles.tabularNums(
                              AppTextStyles.body(
                                  fontSize: 10.5, color: colors.accentBright),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Divider(colors: colors),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.placeDetailIntroSection),
                    Text(
                      place.introduction,
                      style: AppTextStyles.body(color: colors.ink, height: 1.8),
                    ),
                    const SizedBox(height: 24),
                    _Divider(colors: colors),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.placeDetailLocationSection),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(AppIconShape.pin,
                            size: 14, color: colors.accentBright),
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
                          label: l10n.placeDetailOpenInMapApp,
                          icon: AppIconShape.arrowUpRight,
                          onTap: () => _openMap(
                              context,
                              () =>
                                  MapLauncherService.openKakaoMap(place.name)),
                        ),
                        const SizedBox(width: 10),
                        _OutlineButton(
                          label: l10n.placeDetailOpenInNaverMap,
                          icon: AppIconShape.arrowUpRight,
                          onTap: () => _openMap(
                              context,
                              () =>
                                  MapLauncherService.openNaverMap(place.name)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Divider(colors: colors),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.placeDetailPhoneSection),
                    Row(
                      children: [
                        AppIcon(AppIconShape.phone,
                            size: 14, color: colors.accentBright),
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
                      label: l10n.placeDetailCallButton,
                      expand: true,
                      onTap: () => _call(context),
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
            fontSize: 11, color: colors.accentBright, letterSpacing: 1.8),
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
          border: Border.all(color: colors.accent),
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
                  fontSize: 13, color: colors.accentBright, letterSpacing: .3),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              AppIcon(icon!, size: 12, color: colors.accentBright),
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
