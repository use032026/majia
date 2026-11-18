#!/bin/bash
# Simulator-only ad-hoc signing seals LaunchScreen resources without a team,
# certificate, provisioning profile, or device/release signing configuration.
set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_STAMP="$(date +%Y%m%d-%H%M%S)"
DERIVED_PATH="$APP_ROOT/.codex-build/ios-simulator-$BUILD_STAMP"
DESTINATION="${1:-generic/platform=iOS Simulator}"

cd "$APP_ROOT"
flutter build ios --simulator --debug --config-only --no-codesign
xcodebuild \
  -workspace "$APP_ROOT/ios/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_PATH" \
  BUILD_DIR="$APP_ROOT/build/ios" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  DEVELOPMENT_TEAM= \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build

APP_BUNDLE="$APP_ROOT/build/ios/Debug-iphonesimulator/Runner.app"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
echo "Simulator app: $APP_BUNDLE"
echo "Task build data: $DERIVED_PATH"
