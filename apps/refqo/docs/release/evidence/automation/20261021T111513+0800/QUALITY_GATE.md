# Flutter Quality Gate

Generated: 2026-10-21T11:15:13+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/refqo`
Verdict: `passed`
Git: not a Git repository

| Step | Status | Command | Duration | Full log |
| --- | --- | --- | ---: | --- |
| format-check | `passed` | `/opt/homebrew/share/flutter/bin/dart format --output=none --set-exit-if-changed lib test` | 0.716s | `docs/release/evidence/automation/20261021T111513+0800/format-check.log` |
| flutter-analyze | `passed` | `/opt/homebrew/bin/flutter analyze --no-pub` | 2.729s | `docs/release/evidence/automation/20261021T111513+0800/flutter-analyze.log` |
| flutter-test | `passed` | `/opt/homebrew/bin/flutter test --no-pub --reporter expanded` | 6.046s | `docs/release/evidence/automation/20261021T111513+0800/flutter-test.log` |

## Evidence limits

- Formatting, analyzer, and automated tests do not prove simulator or physical-device behavior.
- An Android debug APK is not a Play release artifact; Gradle may create or use a local debug keystore for that explicitly requested build.
- An unsigned iOS archive does not prove signing, installation, upload, TestFlight, or App Review.
- This script never performs production signing, changes production certificates/accounts, uploads, or submits; an explicitly requested Android debug build may create or use a local debug keystore.
