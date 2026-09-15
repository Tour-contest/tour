import 'package:flutter/material.dart';

import 'package:nullnull/app_router.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';
import 'package:nullnull/widgets/fade_slide_in.dart';

/// 음성 입력(듣기) 중 화면 하단에 떠 있는 안내 배지. [AppToast]와 달리 일정
/// 시간 후 자동으로 사라지지 않고, 탭하면 [onTap]을 호출한 뒤 스스로 닫힌다
/// (`ChatInputBar`에서 음성 입력을 중지시키는 용도). `BuildContext` 없이 어디서든
/// 호출할 수 있도록 [rootNavigatorKey]의 오버레이에 직접 올린다.
class VoiceListeningToast {
  VoiceListeningToast._();

  static OverlayEntry? _entry;

  static void show({required VoidCallback onTap}) {
    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    dismiss();

    final entry = OverlayEntry(
      builder: (_) => _VoiceListeningToastView(
        onTap: () {
          onTap();
          dismiss();
        },
      ),
    );
    _entry = entry;
    overlayState.insert(entry);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

class _VoiceListeningToastView extends StatelessWidget {
  const _VoiceListeningToastView({required this.onTap});

  final VoidCallback onTap;

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
          child: Center(
            child: GestureDetector(
              onTap: onTap,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 130,
                  height: 65,
                  child: AspectRatio(
                    aspectRatio: 2,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/toast_slot.png',
                          fit: BoxFit.fill,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context)!
                                    .chatInputVoiceListeningTitle,
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: AppTextStyles.heading(
                                  fontSize: 14,
                                  color: colors.ink,
                                  height: 1.5,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context)!
                                    .chatInputVoiceListeningHint,
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: AppTextStyles.heading(
                                  fontSize: 13,
                                  color: colors.voiceListeningHint,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
