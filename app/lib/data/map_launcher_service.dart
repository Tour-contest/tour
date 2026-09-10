import 'package:url_launcher/url_launcher.dart';

import 'package:nullnull/app_info.dart';
import 'package:nullnull/app_log.dart';

/// 카카오맵/네이버지도 앱의 URL 스킴으로 장소명을 검색해 여는 유틸리티.
/// 좌표 데이터가 아직 없어(`PlaceRecommendation`) 정확한 지점 대신 키워드
/// 검색 스킴을 쓴다. 두 앱 모두 실기기에 설치돼 있지 않으면 스킴을 열 수
/// 없으므로, 호출부는 반환값(`false`)에 따라 안내 문구를 보여줘야 한다.
class MapLauncherService {
  MapLauncherService._();

  static Future<bool> openKakaoMap(String query) => _launch(
        Uri(scheme: 'kakaomap', host: 'search', queryParameters: {'q': query}),
      );

  static Future<bool> openNaverMap(String query) => _launch(
        Uri(scheme: 'nmap', host: 'search', queryParameters: {
          'query': query,
          'appname': AppInfo.package.packageName,
        }),
      );

  static Future<bool> _launch(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      AppLog.logger.e('지도 앱 실행 실패: $uri', error: error);
      return false;
    }
  }
}
