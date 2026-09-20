import 'package:flutter/widgets.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';

import 'package:nullnull/widgets/app_toast.dart';

/// 뒤로가기 2번을 2초 안에 연속 입력하면 앱을 종료하는 mixin.
mixin DoubleBackExitMixin<T extends StatefulWidget> on State<T> {
  DateTime? _lastBackPressed;

  Future<void> handleBackPress() async {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) >
            const Duration(milliseconds: 2000)) {
      _lastBackPressed = now;
      AppToast.show('뒤로가기를 한 번 더 누르면 앱이 종료됩니다.', type: AppToastType.info);
      return;
    }
    await FlutterExitApp.exitApp();
  }
}
