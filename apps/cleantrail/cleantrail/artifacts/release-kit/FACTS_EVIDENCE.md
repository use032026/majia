# Product and privacy evidence

Current display brand: ASTFX. Repository/app root: apps/cleantrail/cleantrail. Version 1.0.0+1.

| Claim | Checked implementation |
| --- | --- |
| CSV, TSV, TXT, XLSX; UTF-8/GBK and worksheet confirmation | lib/data/native_csv_gateway.dart; lib/data/import_decoder.dart; lib/ui/workbench_home.dart |
| Five quality checks and input limits | lib/domain/quality_engine.dart (maxRows, maxColumns, maxCells, maxIssues); NativeCsvGateway.maxFileBytes |
| Decisions and session-local undo | lib/state/workbench_controller.dart (resolveIssue, undo, _undoStack) |
| Five-row compact preview; tap full cell value; validation chart | lib/ui/workbench_home.dart (_TablePreview and numeric chart) |
| Source file is read, never overwritten | NativeCsvGateway.pickDataFile; FileProjectStore stores a separate private project |
| One local project, temporary save and recovery backup | lib/data/file_project_store.dart (load/save/clear) |
| Language and onboarding preferences | lib/data/language_store.dart; lib/data/onboarding_store.dart |
| CSV + Markdown, clean/draft names, report excludes complete source rows | lib/data/native_csv_gateway.dart; lib/domain/export_builder.dart |
| Export files cleaned on return; stale cleanup retried at launch/export | NativeCsvGateway.export/finally and cleanupTemporaryFiles; WorkbenchController.load |
| No application-operated backend, analytics, ads, tracking or AI dependency | pubspec.yaml, all lib imports/network search, iOS and Android manifests |
| No main-manifest camera/photos/mic/location/contact/notification/tracking declarations | ios/Runner/Info.plist; ios/Runner/PrivacyInfo.xcprivacy; android/app/src/main/AndroidManifest.xml |
| Android debug/profile INTERNET is development configuration | android/app/src/debug/AndroidManifest.xml; android/app/src/profile/AndroidManifest.xml |
| iPhone + iPad support | TARGETED_DEVICE_FAMILY = 1,2 in Runner.xcodeproj/project.pbxproj |

Signals in app-facts.json were manually checked against the cited source. They are not a legal or store-policy approval. OS/cloud backups, file providers, sharing destinations and hosting logs are described conditionally rather than attributed to an app-operated server.

## Current official asset specifications consulted

- Apple screenshots: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Apple metadata limits: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Google Play previews: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en

Checked 2026-10-27. Delivered iPhone 1206×2622 and iPad 2064×2752 satisfy the currently listed required slots. Play screenshots are 1080×1920 RGB; feature graphics 1024×500 RGB; the Play icon is 512×512 RGBA.
