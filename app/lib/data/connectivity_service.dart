import 'package:connectivity_plus/connectivity_plus.dart';

/// 네트워크 연결 상태(와이파이/셀룰러 on-off)를 감지한다.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  Stream<bool> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
