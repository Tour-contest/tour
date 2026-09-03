# Flutter 엔진/플러그인 등록 코드에 필요한 규칙은 Flutter Gradle 플러그인이 자동으로
# 추가한다(io.flutter.** 등을 여기서 직접 keep할 필요 없음). 이 파일은 서드파티
# 네이티브 SDK가 리플렉션/직렬화로 클래스를 참조해 R8이 이름을 바꾸면 깨지는 경우에만
# 규칙을 추가한다. 현재 의존 중인 플러그인(kakao_flutter_sdk_user, dio, connectivity_plus,
# shared_preferences, url_launcher, flutter_svg, package_info_plus 등)은 모두 자체
# consumer proguard 규칙을 포함하거나 리플렉션을 쓰지 않아 추가 규칙이 필요 없었다
# (2026-09-03, `flutter build apk --release --obfuscate --split-debug-info=build/symbols`로
# 실제 빌드 성공 확인). 새 네이티브 SDK(Firebase 등)를 추가하면 릴리즈 빌드에서
# ClassNotFoundException 등이 나는지 확인하고, 나면 여기에 규칙을 추가할 것.
