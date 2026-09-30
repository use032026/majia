# Flutter Release Mechanical Preflight

Generated: 2026-09-30T10:27:22+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/reader_edit`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": false} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.readerEdit", "com.example.readerEdit.RunnerTests"], "placeholders": ["com.example.readerEdit"], "expected_bundle_id": "com.example.readerEdit"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/reader_edit/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.readerEdit", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/reader_edit/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/reader_edit/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/path_provider_foundation.framework/path_provider_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/shared_preferences_foundation.framework/shared_preferences_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "path_provider_foundation.framework", "shared_preferences_foundation.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.readerEdit", "archive": "com.example.readerEdit"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `pass` | screenshots | Screenshot PNG dimensions and alpha were inspected. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/reader_edit/docs/release/evidence/runtime/iphone17promax-home-zh-light-store.png", "width": 1320, "height": 2868, "has_alpha": false}] |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/reader_edit/assets/branding/readeredit-icon-source.png", "/Users/starburst/Downloads/app-ui-atlas/reader_edit/build/app/outputs/flutter-apk/app-debug.apk"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/reader_edit/assets/branding/readeredit-icon-source.png` — SHA-256 `01d7dab3abec7bd12b11a3ae33f93a56387d23799bb0afb13c00c381551f3bc2`, 1657046 bytes
- `/Users/starburst/Downloads/app-ui-atlas/reader_edit/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `58df0e7b6ea8c2686773cb60a59a7a007cfc24245b26f41599a312d5ab5dc635`, 146793212 bytes
- `/Users/starburst/Downloads/app-ui-atlas/reader_edit/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `30e60b572db4fff5faea89ee74be6ba522d3bb4c079506ae42fff556de46fad1`, 73976 bytes
- `/Users/starburst/Downloads/app-ui-atlas/reader_edit/docs/release/evidence/runtime/iphone17promax-home-zh-light-store.png` — SHA-256 `01a4a72450e8fac15e471122597e92d4a7aa2ac7824ba43539596cebc80a69a7`, 677938 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
