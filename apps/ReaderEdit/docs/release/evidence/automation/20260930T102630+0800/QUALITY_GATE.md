# Flutter Quality Gate

Generated: 2026-09-30T10:26:30+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/reader_edit`
Verdict: `passed`
Git: not a Git repository

| Step | Status | Command | Duration | Full log |
| --- | --- | --- | ---: | --- |
| format-check | `passed` | `/Users/starburst/fvm/versions/3.35.7/bin/dart format --output=none --set-exit-if-changed lib test` | 0.83s | `docs/release/evidence/automation/20260930T102630+0800/format-check.log` |
| flutter-analyze | `passed` | `/Users/starburst/Downloads/app-ui-atlas/money_box/.fvm/flutter_sdk/bin/flutter analyze --no-pub` | 2.128s | `docs/release/evidence/automation/20260930T102630+0800/flutter-analyze.log` |
| flutter-test | `passed` | `/Users/starburst/Downloads/app-ui-atlas/money_box/.fvm/flutter_sdk/bin/flutter test --no-pub --reporter expanded` | 4.82s | `docs/release/evidence/automation/20260930T102630+0800/flutter-test.log` |
| android-debug-build | `passed` | `/Users/starburst/Downloads/app-ui-atlas/money_box/.fvm/flutter_sdk/bin/flutter build apk --debug --no-pub` | 3.944s | `docs/release/evidence/automation/20260930T102630+0800/android-debug-build.log` |
| ios-unsigned-archive | `passed` | `/Users/starburst/Downloads/app-ui-atlas/money_box/.fvm/flutter_sdk/bin/flutter build ipa --release --no-codesign --no-pub` | 21.912s | `docs/release/evidence/automation/20260930T102630+0800/ios-unsigned-archive.log` |

## Evidence limits

- Formatting, analyzer, and automated tests do not prove simulator or physical-device behavior.
- An Android debug APK is not a Play release artifact; Gradle may create or use a local debug keystore for that explicitly requested build.
- An unsigned iOS archive does not prove signing, installation, upload, TestFlight, or App Review.
- This script never performs production signing, changes production certificates/accounts, uploads, or submits; an explicitly requested Android debug build may create or use a local debug keystore.
