import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nullnull/data/connectivity_service.dart';
import 'package:nullnull/l10n/app_localizations.dart';
import 'package:nullnull/theme/app_colors.dart';
import 'package:nullnull/theme/app_text_styles.dart';

/// 앱 전역에서 네트워크 연결 상태를 감시하다가, 연결이 끊기면 차단 팝업을 띄우고
/// 다시 연결되면 자동으로 닫는다. `MaterialApp.builder`에서 [child]를 감싸 쓴다.
class NetworkStatusListener extends StatefulWidget {
  const NetworkStatusListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<NetworkStatusListener> createState() => _NetworkStatusListenerState();
}

class _NetworkStatusListenerState extends State<NetworkStatusListener> {
  final _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _subscription;
  BuildContext? _dialogContext;

  bool _isOnline = true;
  bool _isDialogOpening = false;

  @override
  void initState() {
    super.initState();
    _subscription =
        _connectivityService.onStatusChanged.listen(_handleStatusChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleStatusChanged(bool isOnline) {
    _isOnline = isOnline;
    if (isOnline) {
      _dismissDialog();
    } else {
      _showDialog();
    }
  }

  Future<void> _showDialog() async {
    if (_isDialogOpening) return;
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) return;
    _isDialogOpening = true;
    await showDialog<void>(
      context: overlayContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        if (_isOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _dismissDialog());
        }
        return const _OfflineDialog();
      },
    );
    _dialogContext = null;
    _isDialogOpening = false;
  }

  void _dismissDialog() {
    final dialogContext = _dialogContext;
    if (dialogContext == null) return;
    Navigator.of(dialogContext).pop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _OfflineDialog extends StatelessWidget {
  const _OfflineDialog();

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
                l10n.networkOfflineDialogTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(fontSize: 17, color: colors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.networkOfflineDialogMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                    fontSize: 12.5, color: colors.ink700, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
