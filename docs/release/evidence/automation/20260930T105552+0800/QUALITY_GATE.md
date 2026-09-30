# Flutter Quality Gate

Generated: 2026-09-30T10:55:52+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/diary`
Verdict: `passed`
Git: not a Git repository

| Step | Status | Command | Duration | Full log |
| --- | --- | --- | ---: | --- |
| format-check | `passed` | `fvm dart format --output=none --set-exit-if-changed lib test` | 0.839s | `docs/release/evidence/automation/20260930T105552+0800/format-check.log` |
| flutter-analyze | `passed` | `fvm flutter analyze --no-pub` | 2.133s | `docs/release/evidence/automation/20260930T105552+0800/flutter-analyze.log` |
| flutter-test | `passed` | `fvm flutter test --no-pub --reporter expanded` | 6.584s | `docs/release/evidence/automation/20260930T105552+0800/flutter-test.log` |
| android-debug-build | `passed` | `fvm flutter build apk --debug --no-pub` | 5.752s | `docs/release/evidence/automation/20260930T105552+0800/android-debug-build.log` |
| ios-unsigned-archive | `passed` | `fvm flutter build ipa --release --no-codesign --no-pub` | 21.036s | `docs/release/evidence/automation/20260930T105552+0800/ios-unsigned-archive.log` |

## Evidence limits

- Formatting, analyzer, and automated tests do not prove simulator or physical-device behavior.
- An Android debug APK is not a Play release artifact; Gradle may create or use a local debug keystore for that explicitly requested build.
- An unsigned iOS archive does not prove signing, installation, upload, TestFlight, or App Review.
- This script never performs production signing, changes production certificates/accounts, uploads, or submits; an explicitly requested Android debug build may create or use a local debug keystore.
