#!/usr/bin/env bash
# 난독화된 안드로이드 릴리즈 빌드를 표준 절차로 만든다.
#
# 사용법:
#   scripts/build_release.sh [apk|appbundle]  (기본값: apk)
#
# 이 스크립트가 하는 일:
#   1. pubspec.yaml의 version(예: 1.0.2+6)을 읽는다.
#   2. `flutter build <apk|appbundle> --release --obfuscate
#      --split-debug-info=...`로 R8(ProGuard)뿐 아니라 Dart 코드까지 난독화한
#      릴리즈 빌드를 만든다.
#   3. 이때 생성되는 Dart 디버그 심볼(.symbols)은 `build/`(gitignore 대상,
#      `flutter clean`으로도 사라짐) 대신 저장소에 커밋되는
#      `debug-symbols/<version>/`로 옮긴다 — Firebase Crashlytics는 R8
#      mapping.txt는 자동으로 업로드/복호화해주지만 Dart 심볼은 그런 기능이
#      없어(`CLAUDE.md`의 `crash_reporting_service.dart` 문단 참고), 나중에
#      `flutter symbolize -i <난독화된 스택트레이스> -d
#      debug-symbols/<version>/app.android-arm64.symbols`로 직접 복호화하려면
#      이 파일을 릴리즈별로 우리가 직접 보관해야 한다.
#
# 새 버전을 배포할 때마다 이 스크립트로 빌드하고, 결과로 생긴
# `debug-symbols/<version>/`를 커밋해둘 것.

set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_TARGET="${1:-apk}"
if [[ "$BUILD_TARGET" != "apk" && "$BUILD_TARGET" != "appbundle" ]]; then
  echo "사용법: $0 [apk|appbundle]" >&2
  exit 1
fi

VERSION=$(grep -E '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//')
if [[ -z "$VERSION" ]]; then
  echo "pubspec.yaml에서 version을 읽지 못했습니다." >&2
  exit 1
fi

SYMBOLS_DIR="debug-symbols/${VERSION}"
mkdir -p "$SYMBOLS_DIR"

echo "▶ 버전 ${VERSION} ${BUILD_TARGET} 릴리즈 빌드를 시작합니다 (심볼: ${SYMBOLS_DIR})"

flutter build "$BUILD_TARGET" --release --obfuscate --split-debug-info="$SYMBOLS_DIR"

echo "✓ 빌드 완료. ${SYMBOLS_DIR}를 git에 커밋해두세요:"
echo "  git add ${SYMBOLS_DIR} && git commit -m \"chore: archive debug symbols for v${VERSION}\""
