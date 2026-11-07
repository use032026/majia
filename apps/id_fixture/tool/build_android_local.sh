#!/bin/bash
# AOT arm64 package for local acceptance. This uses only the standard Android
# debug keystore; it is not a production-signed or store-ready release.
set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_ROOT="$APP_ROOT/artifacts"
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"
if [[ ! -f "$DEBUG_KEYSTORE" ]]; then
  echo "Missing standard Android debug keystore. Build a debug APK first." >&2
  exit 1
fi
if [[ -z "${JAVA_HOME:-}" && -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

cd "$APP_ROOT"
flutter build apk --release --target-platform android-arm64
BUILD_TOOLS="$(python3 - <<'PY'
import os
from pathlib import Path
properties = dict(line.split('=', 1) for line in Path('android/local.properties').read_text().splitlines() if '=' in line)
sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or properties['sdk.dir'])
versions = [p for p in (sdk / 'build-tools').iterdir() if p.is_dir() and all(x.isdigit() for x in p.name.split('.')) and (p / 'apksigner').exists()]
print(max(versions, key=lambda p: tuple(map(int, p.name.split('.')))))
PY
)"
mkdir -p "$OUTPUT_ROOT"
BUILD_VERSION="$(python3 - <<'PY'
from pathlib import Path
print(next(line.split(':', 1)[1].strip().replace('+', '-') for line in Path('pubspec.yaml').read_text().splitlines() if line.startswith('version:')))
PY
)"
LOCAL_APK="$OUTPUT_ROOT/ID-Fixture-$BUILD_VERSION-android-arm64-local-test.apk"
"$BUILD_TOOLS/apksigner" sign \
  --ks "$DEBUG_KEYSTORE" \
  --ks-key-alias androiddebugkey \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "$LOCAL_APK" \
  "$APP_ROOT/build/app/outputs/flutter-apk/app-release.apk"
"$BUILD_TOOLS/apksigner" verify --verbose --print-certs "$LOCAL_APK"
shasum -a 256 "$LOCAL_APK"
echo "Local acceptance APK (arm64, debug certificate): $LOCAL_APK"
