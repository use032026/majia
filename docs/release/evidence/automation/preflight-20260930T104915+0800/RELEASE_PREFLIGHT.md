# Flutter Release Mechanical Preflight

Generated: 2026-09-30T10:49:15+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/diary`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": false} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.diary", "com.example.diary.RunnerTests"], "placeholders": ["com.example.diary"], "expected_bundle_id": "com.example.diary"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/diary/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.diary", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/diary/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/diary/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/path_provider_foundation.framework/path_provider_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "path_provider_foundation.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.diary", "archive": "com.example.diary"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `warning` | screenshots | Screenshots exist but at least one has alpha or is unreadable. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/diary/docs/release/evidence/runtime/iphone-se-thread-closed-zh.png", "width": 750, "height": 1334, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/diary/docs/release/evidence/runtime/ipad-10-empty-zh.png", "width": 1640, "height": 2360, "has_alpha": true}] |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/diary/build/app/outputs/flutter-apk/app-debug.apk", "/Users/starburst/Downloads/app-ui-atlas/diary/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/diary/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `087894205711c1c6edb1fbd156673f469c167cd0abf62e3c79a1f4c16b8fe3d6`, 144352568 bytes
- `/Users/starburst/Downloads/app-ui-atlas/diary/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `d4d2d9a89f3e31cc32804c785a6562c20fc8934e0c550b8b20e4702412927809`, 73808 bytes
- `/Users/starburst/Downloads/app-ui-atlas/diary/docs/release/evidence/runtime/iphone-se-thread-closed-zh.png` — SHA-256 `8312492540f1ac76f1691c0a69e59311c0e8e1f37a5e4cab576437b106a06a28`, 107069 bytes
- `/Users/starburst/Downloads/app-ui-atlas/diary/docs/release/evidence/runtime/ipad-10-empty-zh.png` — SHA-256 `67549da0c98393ad6078ae5d58a25826ab1899edff1023ec74dad104d7a984ab`, 162519 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
