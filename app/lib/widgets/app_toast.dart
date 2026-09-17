import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/fade_slide_in.dart';

enum AppToastType { info }

/// 화면 하단에 잠깐 떴다 사라지는 안내 토스트. `BuildContext` 없이 어디서든
/// 호출할 수 있도록 [rootNavigatorKey]의 오버레이에 직접 올린다.
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    String message, {
    required AppToastType type,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _dismiss();

    final entry = OverlayEntry(
      builder: (_) => _AppToastView(message: message, type: type),
    );
    _entry = entry;
    overlayState.insert(entry);
    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _AppToastView extends StatelessWidget {
  const _AppToastView({required this.message, required this.type});

  final String message;
  final AppToastType type;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned(
      left: 24,
      right: 24,
      bottom: 40,
      child: SafeArea(
        maintainBottomViewPadding: true,
        child: FadeSlideIn(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: colors.graphite,
                border: Border.all(color: colors.toastBorder, width: 0.5),
                borderRadius: BorderRadius.circular(64),
                boxShadow: [
                  BoxShadow(color: colors.toastShadow, blurRadius: 5.3),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(
                    fontSize: 12, color: colors.ink, height: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
