import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  AppInfo._();

  static const String serviceName = '널널';
  static const String developerEmail = 'dev.hie2gw@gmail.com';

  static const String privacyPolicyUrl =
      'https://abounding-clownfish-456.notion.site/nullnull-3db934206e8c809ab911df3124ba9422';
  static const String termsOfServiceUrl =
      'https://abounding-clownfish-456.notion.site/nullnull-3db934206e8c8011a311e783635e96f0';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=kr.co.nullnull';

  /// TODO apple
  static const String appStoreUrl = '';

  static late final PackageInfo package;

  static Future<void> ensureInitialized() async {
    package = await PackageInfo.fromPlatform();
  }
}
