# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (pick a connected device/simulator, or use -d <device_id>)
flutter run
```

## Project Overview

**널널**은 인파를 피해 여유롭고 쾌적한 여행을 원하는 자유여행객을 위한 AI 여행 챗 비서 모바일 앱이다. 실시간 혼잡도 데이터를 기반으로 한적한 대안 여행지를 매칭하고 과밀 분산 여행 코스를 추천한다(자세한 제품 컨셉·화면 스펙은 `docs/DESIGN.md` 참고).

- 대상 플랫폼: iOS, Android (`## 플랫폼 지원` 참고)
- 현재 단계: `lib/data/demo_script.dart`의 canned 스크립트로 동작하는 프로토타입으로, 실제 백엔드/AI 연동은 아직 없다.
- 화면 흐름: 온보딩 → 로그인(SNS 전용) → 채팅(빈 상태 / 대화) → 지난 대화(히스토리) → 설정, 단일 스택 내비게이션(`Navigator`)으로 구성.

## Architecture

Flutter 앱 "널널"(package name `nullnull`, Dart SDK `^3.6.1`)은 AI 여행 챗봇 서비스로, `docs/DESIGN.md`에 정의된 화면 구성(온보딩 → 채팅 → 지난 대화 → 설정)을 기반으로 하되, 온보딩과 채팅 사이에 SNS 전용 로그인 화면(`login_screen.dart`)이 추가되어 있다(`docs/DESIGN.md`에는 아직 반영되지 않음).

- `lib/main.dart` — 앱 진입점. `AppInfo.ensureInitialized()`와 `AppTextScaleController.ensureInitialized()`를 초기화한 뒤 전역 `appTextScaleController`(`late final`)를 통해 `MaterialApp`을 `ValueListenableBuilder<AppFontScale>`로 감싸고, `builder`에서 `MediaQuery`의 `textScaler`를 선택된 배율로 덮어써 앱 전체 글자 크기에 적용한다. 화면 모드(다크 모드) 전환 기능은 사용하지 않는다(`theme: AppTheme.theme` 고정).
- `lib/app_info.dart` — 서비스명, 개발자 이메일, 개인정보처리방침/스토어 URL 등 앱 메타데이터와 `package_info_plus` 기반 `PackageInfo`를 전역으로 제공한다.
- `lib/app_log.dart` — `logger` 패키지를 감싼 `AppLog.logger` 전역 로거.
- `lib/screens/` — `onboarding_screen.dart`, `login_screen.dart`, `chat_screen.dart`, `history_screen.dart`, `settings_screen.dart`. 라우팅은 별도 패키지 없이 `Navigator.push(MaterialPageRoute)`로 처리한다. `login_screen.dart`는 카카오/네이버 SNS 로그인만 제공(회원가입 절차 별도 없음)하며, 실제 SNS 인증 SDK 연동 전 단계라 버튼 탭 시 바로 채팅 화면으로 이동하는 mock 동작이다. `settings_screen.dart`는 "내 정보" 섹션에서 `LoginPreference`에 저장된 마지막 SNS 로그인 수단(없으면 카카오로 가정)을 로그인된 계정으로 간주해 `DemoUser`의 닉네임/이메일 목업 데이터를 보여주고, "글자 크기" 섹션에서 `AppTextScaleController`를 통해 접근성용 글자 크기(작게/보통/크게/아주 크게)를 라디오 목록으로 선택할 수 있다. 화면 모드(다크 모드) 설정 항목은 없다.
- `lib/widgets/` — `app_header.dart`, `app_icon.dart`(Lucide 스타일 아이콘을 `CustomPainter`로 직접 그리는 자체 아이콘 시스템, 외부 아이콘 폰트 의존성 없음. `kakao`/`naver` 등 SNS 로그인 아이콘도 브랜드 컬러 없이 골드 스트로크로 동일하게 그린다), `fade_slide_in.dart`, `chat/` 하위에 채팅 화면 전용 위젯들.
- `lib/theme/` — `app_colors.dart`(`ThemeExtension<AppColors>`로 라이트 팔레트만 정의, `AppColors.of(context)`로 조회), `app_text_styles.dart`, `app_theme.dart`(`AppTheme.theme` — 라이트 고정, 다크 테마/모드 전환 없음), `app_text_scale_controller.dart`(`AppFontScale` enum(글자 크기 배율 4단계) + `ValueNotifier<AppFontScale>` + `shared_preferences`로 사용자의 글자 크기 선택을 영속화).
- `lib/data/demo_script.dart` — 데모/프로토타입용 대화 스크립트 데이터. 실제 백엔드 연동 전 단계로, 서비스 로직/API 레이어는 아직 없다.
- `lib/data/login_preference.dart` — 로그인 화면의 "최근 로그인" 뱃지 표시를 위해 마지막으로 사용한 SNS 로그인 수단(`SnsProvider`)을 `shared_preferences`에 저장/조회한다(`app_text_scale_controller.dart`와 동일한 영속화 패턴). `SnsProviderLabel` extension으로 화면 표시용 한글 라벨(`카카오`/`네이버`)을 제공한다.
- `lib/data/demo_user.dart` — 설정 화면 "내 정보"에 보여줄 데모 프로필(닉네임/마스킹된 이메일)을 `SnsProvider`별로 고정 매핑한 목업 데이터. 실제 회원 시스템 연동 전 단계.
- 새 파일의 `lib/` 내부 import는 상대 경로(`../`, `./`) 대신 `package:nullnull/...` 형태를 사용한다(`analysis_options.yaml`의 `always_use_package_imports` 규칙).
- `test/widget_test.dart` — 온보딩 → 로그인(카카오 탭) → 채팅 → 지난 대화 → 설정으로 이동하며 설정 화면의 "내 정보"(카카오 계정 목업)·"글자 크기"까지 검증하는 위젯 테스트. `PackageInfo`/`SharedPreferences` 목 값 설정과 `AppInfo`/`AppTextScaleController` 초기화를 `setUpAll`에서 실제 `main()`과 동일한 순서로 재현해야 한다.
- `integration_test/screenshot_flow_test.dart` — 실기기/시뮬레이터에서 화면을 순서대로 전환하며 스토어 스크린샷을 캡처하기 위한 흐름. 각 화면에서 `SCREENSHOT_READY:<name>`을 출력한 뒤 대기하므로, 그 사이 외부에서 `xcrun simctl io <device> screenshot` 등으로 캡처한다.
- `docs/` — `DESIGN.md`(디자인 시스템), `PRIVACY.md`, `STORE_LISTING.md`, `screenshots/`, `graphics/` 등 스토어 등록/디자인 관련 산출물. 저장소 루트 `.gitignore`가 `docs/`를 무시하도록 되어 있음(의도적으로 유지 중, 임의로 변경하지 말 것).
- 플랫폼 폴더(`android/`, `ios/`, `web/`)는 Flutter가 생성한 표준 플랫폼 셸이며, 커스텀 네이티브 코드는 없다.
- Linting은 `analysis_options.yaml`(`package:flutter_lints/flutter.yaml` + `always_use_package_imports`)로 설정되어 있다.

## Design

디자인 시스템(색상·타이포그래피·화면별 레이아웃)과 카피 톤은 `docs/DESIGN.md`를 기준으로 삼는다. 화면이나 컴포넌트를 새로 만들거나 수정하기 전에 먼저 `docs/DESIGN.md`를 확인할 것.

## 플랫폼 지원

iOS, Android만 지원한다.

## 코드 규칙 (Code Convention)

### 네이밍 & 파일 구조

| 대상 | 규칙 | 예시 |
|------|------|------|
| 폴더 / 파일명 | `snake_case` | `login_screen.dart` |
| 클래스명 / extension / mixin | `PascalCase` | `LoginScreen` |
| 변수 / 메서드 / 함수 | `camelCase` | `_emailController` |
| 상수 | `camelCase` (static const) | `AppInfo.serviceName` |
| 프라이빗 멤버 | `_` 접두사 | `_navigate()` |
| 화면 파일 위치 | `lib/screens/` 바로 하위에 배치 (도메인별 하위 폴더 없음) | `lib/screens/chat_screen.dart` |

### Dart / Flutter 스타일

- 불변 위젯과 값에는 `const` 키워드를 우선 사용한다.
- 재사용 단위의 UI 블록은 프라이빗 클래스(`_WidgetName`)로 분리한다.
- 인스턴스화가 불필요한 유틸 클래스는 `private constructor` + `static` 멤버 패턴을 유지한다. (`AppColors`, `AppLog` 참고)
- `late final`을 적극 활용하여 불필요한 nullable을 줄인다.
- `SafeArea` 위젯 사용 시, `maintainBottomViewPadding: true` 값을 기본으로 사용한다.
- `SingleChildScrollView` 위젯 사용 시, `physics: const BouncingScrollPhysics()` 값을 기본 값으로 사용한다.
- 간단히 실행되는 함수의 경우 블록형 보다는 화살표 형으로 작성한다. (router 쪽은 블록형으로 작성하도록 놔둘 것.)
- analysis_options.yaml 파일을 참조하여 규칙에 위배되지 않는 코드를 작성한다.
- `AnimationController`는 반드시 `StatefulWidget`의 `initState`에서 생성하고 `dispose()`에서 해제한다. `SingleTickerProviderStateMixin` (1개) 또는 `TickerProviderStateMixin` (복수) 사용.
- 한글 IME(천지인 등) 입력을 허용하는 `TextInputFormatter`는 `FilteringTextInputFormatter.allow()` 대신 `_AllowedCharsFormatter` 패턴(denied regex + composing 구간 스킵)을 사용한다.
- 비동기 작업 중 화면 이탈을 막을 때는 `PopScope(canPop: !_isLoading)`으로 Scaffold를 감싼다. 화면 터치 차단은 `Stack` + `ColoredBox` 오버레이로 처리한다.
- `Dialog` 위젯은 내부적으로 키보드 높이를 처리하므로, builder에서 `Padding(bottom: viewInsets.bottom)`을 별도로 추가하지 않는다.

### 색상 / 텍스트 스타일

- 인라인 `Color()` / `TextStyle()` 선언 **금지**
- 반드시 `AppColors` / `AppTextStyles` 사용
- 변형이 필요한 경우에만 `.copyWith()` 활용
- 신규 색상·스타일이 필요하면 각 클래스에 추가한 뒤 사용

### 로깅

- `print()` **금지**. 반드시 `AppLog.logger`를 사용한다.

```dart
AppLog.logger.d('debug 메시지');
AppLog.logger.i('info 메시지');
AppLog.logger.w('warning 메시지');
AppLog.logger.e('error 메시지');
```

## 금지사항 (Do Not)

- 외부 라이브러리를 새로 추가하기 전 반드시 확인 요청할 것
- 색상·경로·텍스트 스타일 하드코딩 금지 (위 코드 규칙 참조)

## 작업 규칙 (Work Rules)

- 코드 변경 시에는 CLAUDE.md도 변경된 내용이 반영되도록 수정한다.
- 프롬프트 실행 시 및 코드 변경 시에는 `docs/claude_history/yyyyMMdd.md` 파일에 템플릿에 맞추어 내용을 추가한다.