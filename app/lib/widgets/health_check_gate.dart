import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';

import 'package:nullnull/data/attribution_service.dart';
import 'package:nullnull/data/health_check_service.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 앱 실행 시 딱 한 번 백엔드 헬스 체크([HealthCheckService.check])를 수행한다. 성공하면
/// [AttributionService.fetch]로 출처 표기 문구를 조회해 전역에 저장해두고, 서버에 문제가
/// 있으면 닫을 수 없는 안내 팝업을 띄운 뒤 사용자가 "앱 종료"를 누르면 [FlutterExitApp]으로
/// 앱을 종료한다. `MaterialApp.builder`에서 [child]를 감싸 쓴다.
class HealthCheckGate extends StatefulWidget {
  const HealthCheckGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<HealthCheckGate> createState() => _HealthCheckGateState();
}

class _HealthCheckGateState extends State<HealthCheckGate> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    if (_hasChecked) return;
    _hasChecked = true;

    final isHealthy = await HealthCheckService.check();
    if (isHealthy) {
      unawaited(AttributionService.fetch());
      return;
    }
    if (!mounted) return;

    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null || !overlayContext.mounted) return;
    await showDialog<void>(
      context: overlayContext,
      barrierDismissible: false,
      builder: (_) => const _ServerUnavailableDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ServerUnavailableDialog extends StatelessWidget {
  const _ServerUnavailableDialog();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: colors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.serverUnavailableDialogTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 17, color: colors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.serverUnavailableDialogMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                    fontSize: 12.5, color: colors.ink700, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () => FlutterExitApp.exitApp(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.accent,
                    side: BorderSide(color: colors.accent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    overlayColor: colors.accentTint08,
                  ),
                  child: Text(
                    l10n.serverUnavailableDialogExitButton,
                    style: AppTextStyles.body(
                      fontSize: 13.5,
                      color: colors.paper,
                      letterSpacing: .3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
