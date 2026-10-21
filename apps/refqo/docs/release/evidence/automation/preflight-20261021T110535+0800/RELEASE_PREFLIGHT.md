# Flutter Release Mechanical Preflight

Generated: 2026-10-21T11:05:35+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/refqo`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": false} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.refqo", "com.example.refqo.RunnerTests"], "placeholders": ["com.example.refqo"], "expected_bundle_id": "com.example.refqo"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.refqo", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/refqo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/refqo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/file_selector_ios.framework/file_selector_ios_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/path_provider_foundation.framework/path_provider_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/share_plus.framework/share_plus_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "file_selector_ios.framework", "integration_test.framework", "path_provider_foundation.framework", "share_plus.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.refqo", "archive": "com.example.refqo"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `warning` | screenshots | Screenshots exist but at least one has alpha or is unreadable. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/01-onboarding.png", "width": 750, "height": 1334, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/02-empty-plan.png", "width": 750, "height": 1334, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/03-supply-devices.png", "width": 750, "height": 1334, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/04-replace-co |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/refqo/build/app/outputs/flutter-apk/app-debug.apk"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/refqo/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `e1d6b6d8eab466d3cab24d663b054e3971a20c5c13e303b0e77ea7c9d7ee61f6`, 81307668 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `0a535d236e65b5dd107db982321c597451a9fb94092ecdce4bb1d89fc92e945f`, 74128 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/01-onboarding.png` — SHA-256 `93279bb67ee51d1b26df78da97012d233a3b7fcbac0fd96e27b7076a0b4b97e6`, 117254 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/02-empty-plan.png` — SHA-256 `6520060784427b251a4951539a053baf58a656caf1b10fecaaf2676de0a2034e`, 107335 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/03-supply-devices.png` — SHA-256 `e1611aa99376ec056930685e0104aa0c1e2654de4945edd3e7b49e1a8bdfd26b`, 104981 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/04-replace-confirm.png` — SHA-256 `d3d6dde6ca7b50a9ec5ce884806d67cc90f41ba67f9e7bc17db69915ef2fb76b`, 114374 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/05-pooled-plan.png` — SHA-256 `aab4b28442ac0a49cf0ee4acc4030c752efa380285473b5f667a264f94045969`, 104420 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/06-sixty-day-plan.png` — SHA-256 `267c03509f39851b6f5980c97978dfa5332d43ef65b57cacab22f6c09e60cec2`, 98440 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/07-ledger.png` — SHA-256 `073955b3405c727c85f79aec2d40f32de6595c1f412668c8f18afb1d94853679`, 97103 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/08-settings-zh-dark.png` — SHA-256 `5b90b0c966e89c05241493fce630967e3f10c23c05881c2b21365dc762101097`, 97305 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/09-returning-zh-dark.png` — SHA-256 `1e81cf0a38ed3d761e01de8787caa3f8168e5028fd232d66913b9c519816add9`, 102948 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se/10-replay-zh.png` — SHA-256 `1bedb878f9aca0820e2f5c7b0ed48b6c68d24aa7b6961f52f6620413324d0578`, 118066 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
