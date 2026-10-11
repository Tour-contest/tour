import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/app_log.dart';

/// 카카오맵/네이버지도 앱의 URL 스킴으로 장소명을 검색해 여는 유틸리티.
/// 좌표 데이터가 아직 없어(`PlaceRecommendation`) 정확한 지점 대신 키워드
/// 검색 스킴을 쓴다. 앱이 설치돼 있지 않으면 각 서비스의 공식 문서가 안내하는
/// 대로 스토어의 해당 앱 페이지로 대신 이동해 설치를 유도한다 — 그것마저
/// 실패하는 극단적인 경우(브라우저조차 없는 등)에만 호출부가 반환값(`false`)에
/// 따라 안내 문구를 보여주면 된다.
class MapLauncherService {
  MapLauncherService._();

  static const _kakaoMapAndroidStore =
      'https://play.google.com/store/apps/details?id=net.daum.android.map';
  static const _kakaoMapIosStore = 'https://apps.apple.com/app/id304608425';
  static const _naverMapAndroidStore =
      'https://play.google.com/store/apps/details?id=com.nhn.android.nmap';
  static const _naverMapIosStore = 'https://apps.apple.com/app/id311867728';

  static Future<bool> openKakaoMap(String query) => _launch(
        Uri(scheme: 'kakaomap', host: 'search', queryParameters: {'q': query}),
        androidStoreUrl: _kakaoMapAndroidStore,
        iosStoreUrl: _kakaoMapIosStore,
      );

  static Future<bool> openNaverMap(String query) => _launch(
        Uri(scheme: 'nmap', host: 'search', queryParameters: {
          'query': query,
          'appname': AppInfo.package.packageName,
        }),
        androidStoreUrl: _naverMapAndroidStore,
        iosStoreUrl: _naverMapIosStore,
      );

  /// 좌표(위도/경도)가 있는 지점을 정확히 짚어서 연다(`attraction_detail_screen.dart`
  /// 처럼 `AttractionSummary.mapX`(경도)/`mapY`(위도)가 있는 경우 — 관광공사
  /// TourAPI 관례상 `mapx`는 경도, `mapy`는 위도). 카카오맵은 `look` 스킴에
  /// 좌표만 실어 보낸다(라벨 표시는 place id가 있어야 가능해 이 스킴으로는
  /// 지원 안 됨). 네이버지도는 공식 문서의 `place` 스킴(`lat`/`lng`/`name`/`appname`)을
  /// 그대로 쓴다.
  static Future<bool> openKakaoMapAt(double lat, double lng) => _launch(
        Uri(scheme: 'kakaomap', host: 'look', queryParameters: {
          'p': '$lat,$lng',
        }),
        androidStoreUrl: _kakaoMapAndroidStore,
        iosStoreUrl: _kakaoMapIosStore,
      );

  static Future<bool> openNaverMapAt(double lat, double lng, String name) =>
      _launch(
        Uri(scheme: 'nmap', host: 'place', queryParameters: {
          'lat': '$lat',
          'lng': '$lng',
          'name': name,
          'appname': AppInfo.package.packageName,
        }),
        androidStoreUrl: _naverMapAndroidStore,
        iosStoreUrl: _naverMapIosStore,
      );

  static Future<bool> _launch(
    Uri uri, {
    required String androidStoreUrl,
    required String iosStoreUrl,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      AppLog.logger.e('지도 앱 실행 실패: $uri', error: error);
    }
    final storeUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? iosStoreUrl
        : androidStoreUrl;
    try {
      return await launchUrl(Uri.parse(storeUrl),
          mode: LaunchMode.externalApplication);
    } catch (error) {
      AppLog.logger.e('스토어 이동 실패: $storeUrl', error: error);
      return false;
    }
  }
}
