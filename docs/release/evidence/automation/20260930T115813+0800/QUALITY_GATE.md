# Flutter Quality Gate

Generated: 2026-09-30T11:58:13+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/reader_edit`
Verdict: `passed`
Git: not a Git repository

| Step | Status | Command | Duration | Full log |
| --- | --- | --- | ---: | --- |
| format-check | `passed` | `/opt/homebrew/share/flutter/bin/dart format --output=none --set-exit-if-changed lib test` | 0.757s | `docs/release/evidence/automation/20260930T115813+0800/format-check.log` |
| flutter-analyze | `passed` | `/opt/homebrew/bin/flutter analyze --no-pub` | 1.738s | `docs/release/evidence/automation/20260930T115813+0800/flutter-analyze.log` |
| flutter-test | `passed` | `/opt/homebrew/bin/flutter test --no-pub --reporter expanded` | 4.483s | `docs/release/evidence/automation/20260930T115813+0800/flutter-test.log` |
| android-debug-build | `passed` | `/opt/homebrew/bin/flutter build apk --debug --no-pub` | 5.88s | `docs/release/evidence/automation/20260930T115813+0800/android-debug-build.log` |
| ios-unsigned-archive | `passed` | `/opt/homebrew/bin/flutter build ipa --release --no-codesign --no-pub` | 25.144s | `docs/release/evidence/automation/20260930T115813+0800/ios-unsigned-archive.log` |

## Evidence limits

- Formatting, analyzer, and automated tests do not prove simulator or physical-device behavior.
- An Android debug APK is not a Play release artifact; Gradle may create or use a local debug keystore for that explicitly requested build.
- An unsigned iOS archive does not prove signing, installation, upload, TestFlight, or App Review.
- This script never performs production signing, changes production certificates/accounts, uploads, or submits; an explicitly requested Android debug build may create or use a local debug keystore.
