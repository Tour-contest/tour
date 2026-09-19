import 'package:flutter/material.dart';

import 'package:nullnull/data/map_launcher_service.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/app_toast.dart';

/// "지도로 보기" 액션 시트(`assets/images/STEP 1 · 앱 선택 시트.png` 시안). 카카오맵/
/// 네이버지도 중 하나를 고르면 연다. [openKakaoMap]/[openNaverMap]을 주지 않으면
/// [MapLauncherService]로 [placeName]을 검색해 여는 기본 동작을 쓰고(좌표가
/// 없는 호출부), 주면 그 함수를 그대로 쓴다(`attraction_detail_screen.dart`처럼
/// 좌표가 있으면 정확한 지점을 여는 `openKakaoMapAt`/`openNaverMapAt`을 넘길 수 있음).
/// 앱이 미설치면 [MapLauncherService]가 스토어로 대신 이동시키고, 그마저
/// 실패하면(브라우저조차 없는 극단적인 경우) [AppToast]로 안내한다.
class MapAppSheet extends StatelessWidget {
  const MapAppSheet({
    super.key,
    required this.placeName,
    this.openKakaoMap,
    this.openNaverMap,
  });

  final String placeName;
  final Future<bool> Function()? openKakaoMap;
  final Future<bool> Function()? openNaverMap;

  static Future<void> show(
    BuildContext context, {
    required String placeName,
    Future<bool> Function()? openKakaoMap,
    Future<bool> Function()? openNaverMap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MapAppSheet(
        placeName: placeName,
        openKakaoMap: openKakaoMap,
        openNaverMap: openNaverMap,
      ),
    );
  }

  Future<void> _open(
      BuildContext context, Future<bool> Function() launch) async {
    // `pop()` 직후 시트가 곧바로 사라지므로, 이후 await에서 context가 이미
    // unmounted 상태일 수 있다 — 닫기 전에 문구를 미리 꺼내둔다.
    final unavailableMessage =
        AppLocalizations.of(context)!.mapAppSheetUnavailable;
    Navigator.of(context).pop();
    final opened = await launch();
    if (opened) return;
    AppToast.show(unavailableMessage, type: AppToastType.info);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(
        50,
        28,
        50,
        MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.graphite, colors.mapSheetGradientEnd],
        ),
        border: Border(
          top: BorderSide(color: colors.inputBarBorder, width: 4),
          left: BorderSide(color: colors.inputBarBorder, width: 4),
          right: BorderSide(color: colors.inputBarBorder, width: 4),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.mapAppSheetTitle(placeName),
            textAlign: TextAlign.center,
            style: AppTextStyles.heading(fontSize: 18, color: colors.ink)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          _SheetButton(
            label: l10n.mapAppSheetKakaoButton,
            onTap: () => _open(
                context,
                openKakaoMap ??
                    () => MapLauncherService.openKakaoMap(placeName)),
          ),
          const SizedBox(height: 16),
          _SheetButton(
            label: l10n.mapAppSheetNaverButton,
            onTap: () => _open(
                context,
                openNaverMap ??
                    () => MapLauncherService.openNaverMap(placeName)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.mapAppSheetCancel,
              style: AppTextStyles.body(
                      fontSize: 13, color: colors.ink600, height: 1.5)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.graphite,
          side: BorderSide(color: colors.inputBarBorder, width: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(
          label,
          style: AppTextStyles.heading(
                  fontSize: 14, height: 1.5, color: colors.ink)
              .copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
