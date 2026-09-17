# Flutter 엔진/플러그인 등록 코드에 필요한 규칙은 Flutter Gradle 플러그인이 자동으로
# 추가한다(io.flutter.** 등을 여기서 직접 keep할 필요 없음). 이 파일은 서드파티
# 네이티브 SDK가 리플렉션/직렬화로 클래스를 참조해 R8이 이름을 바꾸면 깨지는 경우에만
# 규칙을 추가한다. 현재 의존 중인 플러그인(kakao_flutter_sdk_user, dio, connectivity_plus,
# shared_preferences, url_launcher, flutter_svg, package_info_plus, firebase_core,
# firebase_analytics, firebase_crashlytics 등)은 모두 자체 consumer proguard 규칙을
# 포함하거나 리플렉션을 쓰지 않아 추가 규칙이 필요 없었다
# (2026-09-03 최초 확인, 2026-09-16 Firebase Crashlytics/Analytics 추가 후 재확인 —
# `flutter build apk --release --obfuscate --split-debug-info=build/symbols`로 빌드 성공,
# `build/app/outputs/mapping/release/mapping.txt`에 missing_rules 경고 없음, Crashlytics
# 매핑 파일 업로드 연동(`build/app/crashlytics/release/mappingFileId.txt`)도 정상 생성됨을
# 확인했고, 이 난독화 APK를 실기기에 설치해 카카오 로그인까지 실제로 성공하는 것도 확인함).
# 새 네이티브 SDK를 추가하면 릴리즈 빌드에서 ClassNotFoundException 등이 나는지 확인하고,
# 나면 여기에 규칙을 추가할 것.

# 카카오 개발자 문서(https://developers.kakao.com/docs/latest/ko/android/getting-started#proguard)가
# 안내하는 프로가드 규칙 — [실서버/코드로 확인함] 이 문서는 네이티브 안드로이드 SDK
# (com.kakao.sdk:v2-user/v2-auth/v2-common을 Kotlin/Java에서 직접 쓰는 앱) 기준이고,
# 이 프로젝트가 쓰는 kakao_flutter_sdk_user/auth/common(Flutter 플러그인)은 그 네이티브
# SDK를 감싼 게 아니라 androidx.browser(Custom Tabs)만 의존하는 별개의 순수 Dart
# 구현체라(각 플러그인의 android/build.gradle 확인), 지금 이 앱엔 com.kakao.sdk.*.model.*
# (네이티브 SDK 모델)나 retrofit2/okhttp/bouncycastle 클래스 자체가 존재하지 않는다
# (release mapping.txt에 com.kakao.sdk.flutter.* 브릿지 코드만 있고 그 외엔 전혀 없음,
# 이 프로젝트는 Retrofit이 아니라 Dio를 씀). 즉 지금은 실질적으로 no-op이지만, 플러그인이
# 향후 버전에서 네이티브 SDK 의존성을 추가할 가능성에 대비해 문서 그대로 미리 넣어둔다
# (있어도 해가 없음 — 존재하지 않는 클래스에 대한 -keep/-dontwarn은 R8이 그냥 무시함).
-keep class com.kakao.sdk.**.model.* { <fields>; }

# https://github.com/square/okhttp/pull/6792
-dontwarn org.bouncycastle.jsse.**
-dontwarn org.conscrypt.*
-dontwarn org.openjsse.**

# retrofit2 (with r8 full mode)
-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface <1>
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation
-if interface * { @retrofit2.http.* public *** *(...); }
-keep,allowoptimization,allowshrinking,allowobfuscation class <3>
-keep,allowobfuscation,allowshrinking class retrofit2.Response
