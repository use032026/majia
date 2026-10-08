# Flutter Release Mechanical Preflight

Generated: 2026-10-08T16:23:10+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/somniloquy`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": true, "root": "/Users/starburst/Downloads/app-ui-atlas/somniloquy", "branch": "master", "sha": null, "dirty": true, "status_short": "?? .gitignore\n?? .metadata\n?? README.md\n?? analysis_options.yaml\n?? android/\n?? assets/\n?? docs/\n?? ios/\n?? lib/\n?? pubspec.lock\n?? pubspec.yaml\n?? test/"} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.somniloquy", "com.example.somniloquy.RunnerTests"], "placeholders": ["com.example.somniloquy"], "expected_bundle_id": "com.example.somniloquy"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/somniloquy/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.somniloquy", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/somniloquy/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/somniloquy/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/path_provider_foundation.framework/path_provider_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/record_ios.framework/record_ios_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "audioplayers_darwin.framework", "path_provider_foundation.framework", "record_ios.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.somniloquy", "archive": "com.example.somniloquy"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `warning` | screenshots | Screenshots exist but at least one has alpha or is unreadable. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/somniloquy/docs/release/evidence/runtime/iphone-se-zh-tonight.png", "width": 750, "height": 1334, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/somniloquy/docs/release/evidence/runtime/ipad-pro-11-zh-tonight.png", "width": 1668, "height": 2420, "has_alpha": true}] |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/somniloquy/assets/app_icon_1024.png", "/Users/starburst/Downloads/app-ui-atlas/somniloquy/build/app/outputs/flutter-apk/app-debug.apk"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/somniloquy/assets/app_icon_1024.png` — SHA-256 `0e01bde05f61cd3cae9a6a9e5e23279b49ddd8924b2171badfcd6440393c6166`, 947390 bytes
- `/Users/starburst/Downloads/app-ui-atlas/somniloquy/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `527ed851d2f3c8c72da860ecffdd0e62623e567929c1e199dec1731042cc0996`, 145200602 bytes
- `/Users/starburst/Downloads/app-ui-atlas/somniloquy/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `68b6de3a4ca00c29ea6196f6a0d88f429eb7b29e63de53ccdf13baf8bbad0b63`, 74080 bytes
- `/Users/starburst/Downloads/app-ui-atlas/somniloquy/docs/release/evidence/runtime/iphone-se-zh-tonight.png` — SHA-256 `9a026130a20984eaea8b0cc4f99a08f76d281654a8c0050f5f53c9d83ab6492a`, 115208 bytes
- `/Users/starburst/Downloads/app-ui-atlas/somniloquy/docs/release/evidence/runtime/ipad-pro-11-zh-tonight.png` — SHA-256 `f06aac23bc7c09c695fa50da124352c7fb771bfc3189d126a6b483c01d7926e9`, 210408 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
