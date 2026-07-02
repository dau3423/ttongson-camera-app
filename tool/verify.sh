#!/usr/bin/env bash
# 완료 게이트: 포맷 검사 + 정적 분석 + 테스트. 하나라도 실패하면 non-zero로 종료.
# 루프의 각 태스크 끝, 그리고 "완료" 주장 전에 실행한다.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f pubspec.yaml ]; then
  echo "⏭  pubspec.yaml 없음 — Task 1(flutter create) 전에는 건너뜀"
  exit 0
fi

echo "▶ dart format (검사만)"
dart format --output=none --set-exit-if-changed lib test

# NOTE: `flutter analyze` crashes on this repo's Korean path (똥손카메라) due to an
# analysis-server LSP bug. `dart analyze` is unaffected and honors analysis_options.yaml
# (flutter_lints), so we use it as the gate.
echo "▶ dart analyze"
dart analyze lib test

echo "▶ flutter test"
flutter test

echo "✅ verify 통과"
