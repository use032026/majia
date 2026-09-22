# Flutter Release Mechanical Preflight

Generated: 2026-09-22T13:25:38+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/steady21`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": false} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.steady21", "com.example.steady21.RunnerTests"], "placeholders": ["com.example.steady21"], "expected_bundle_id": "com.example.steady21"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `warning` | preview_labels | Potential prototype/demo wording remains in app-facing source. | {"hits": ["lib/copy.dart:148", "lib/copy.dart:149"], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/steady21/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.steady21", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/steady21/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/steady21/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/path_provider_foundation.framework/path_provider_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "path_provider_foundation.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.steady21", "archive": "com.example.steady21"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `warning` | screenshots | Screenshots exist but at least one has alpha or is unreadable. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/iphone-16e-ios18_3-today-en-light.png", "width": 1170, "height": 2532, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/ipad-pro-11-ios18_3-journey-top.png", "width": 1668, "height": 2420, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/ipad-pro-11-ios18_3-journey-tail.png", "width": 1668, "height": 2420, "has_alpha": true}] |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/steady21/build/app/outputs/flutter-apk/app-debug.apk", "/Users/starburst/Downloads/app-ui-atlas/steady21/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner", "/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/automation/20260922T130811+0800/quality-gate.json", "/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/seed-ipad.json"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/steady21/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `c3ee9a35db6b89578d9629fa08cc40253506c598fc2a2cf1d91901c2954475cd`, 144487426 bytes
- `/Users/starburst/Downloads/app-ui-atlas/steady21/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `2aa50e0a9932a2de305a5f32378059cd0c099706085989df1562ac9af078c863`, 73808 bytes
- `/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/automation/20260922T130811+0800/quality-gate.json` — SHA-256 `834c9af642490c0b258950403533bffaa6e2c28f6ca529a9e11cd12d252e0542`, 3188 bytes
- `/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/seed-ipad.json` — SHA-256 `7bb6f71ec7a22e420d39c734a7ff116cb86b6f4b5625ee1858ede489c8256776`, 5006 bytes
- `/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/iphone-16e-ios18_3-today-en-light.png` — SHA-256 `455db9fb9d9b7cd330be70413e80809a40f6b65bfb3ebaf4e4d2ed48492672d7`, 283204 bytes
- `/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/ipad-pro-11-ios18_3-journey-top.png` — SHA-256 `7a11b669a45b7b83acf6f67a43cad745cf87f24f45fac25a45378edf4e65dabc`, 319448 bytes
- `/Users/starburst/Downloads/app-ui-atlas/steady21/docs/release/evidence/runtime/ipad-pro-11-ios18_3-journey-tail.png` — SHA-256 `0a2edfb27482cc7b8e0dd69df5aa082769c387d0bfc3598d15021dc23b80d2ee`, 459603 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
