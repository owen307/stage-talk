#!/usr/bin/env bash
# Build a debug APK that contains the arm64-v8a Flutter engine.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH" >&2
  exit 1
fi

flutter pub get
flutter build apk --debug --target-platform android-arm64

mkdir -p dist
if [[ -f build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk ]]; then
  cp -f build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk dist/stage-talk-arm64-debug.apk
elif [[ -f build/app/outputs/flutter-apk/app-debug.apk ]]; then
  cp -f build/app/outputs/flutter-apk/app-debug.apk dist/stage-talk-arm64-debug.apk
else
  echo "APK was not produced" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum dist/stage-talk-arm64-debug.apk
fi
echo "Wrote dist/stage-talk-arm64-debug.apk"
