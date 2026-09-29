# Flutter Release Mechanical Preflight

Generated: 2026-09-29T17:42:28+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/money_box`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": false} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.paceJar", "com.example.paceJar.RunnerTests"], "placeholders": ["com.example.paceJar"], "expected_bundle_id": null} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/money_box/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.paceJar", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "13.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/money_box/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/money_box/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/shared_preferences_foundation.framework/shared_preferences_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "shared_preferences_foundation.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.paceJar", "archive": "com.example.paceJar"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `pass` | screenshots | Screenshot PNG dimensions and alpha were inspected. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPhone-6.9/01-pace.png", "width": 1320, "height": 2868, "has_alpha": false}, {"path": "/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPhone-6.9/02-recovery.png", "width": 1320, "height": 2868, "has_alpha": false}, {"path": "/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPhone-6.9/03-timeline.png", "width": 1320, "height": 2868, "has_alpha": false}, {"path": "/Users/starburst/Downloads/app-ui-atlas/m |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/money_box/build/app/outputs/flutter-apk/app-debug.apk", "/Users/starburst/Downloads/app-ui-atlas/money_box/docs/product/assets/pacejar-icon.svg"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/money_box/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `e510edd23576ca29cc58663d51c70de12199cc914aa4212efe9de58c4c451edf`, 145360544 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/product/assets/pacejar-icon.svg` — SHA-256 `958e4d4fa1f813706f7d489d2d42f9a89360f43cdd96908ccd36a478243a5e97`, 522 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `a1800ceaf2ff17bfe9081296a277607681edb4a7655ae8ba1bf58472f86c6f1a`, 75080 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPhone-6.9/01-pace.png` — SHA-256 `69ec37e167c40508a8c9fedf2f4e6cc2fa9b2a5fa19b8de8212eaf8a0e44122c`, 193891 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPhone-6.9/02-recovery.png` — SHA-256 `1bc029ca7e94799e43184d6c8d21456a24a693754faa28a7f07d6d79e03d17fa`, 195906 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPhone-6.9/03-timeline.png` — SHA-256 `493892042605d3d46696db9363575f0d4f3dd5acdf8284d3f6e76b4782608caa`, 200353 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/en-iPhone-6.9/01-timeline-dark.png` — SHA-256 `1fc19a9129a700761fadaf3cbeca91e83e02511e93755f0615ed0c100b762031`, 186650 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/en-iPhone-6.9/02-pace-dark.png` — SHA-256 `b1fc1a2cdc284c26c0136ce3e6de77bd9a88ce481454a0c56e09b794c3cb92cf`, 195089 bytes
- `/Users/starburst/Downloads/app-ui-atlas/money_box/docs/release/evidence/store-screenshots/zh-iPad-13/01-pace.png` — SHA-256 `5388ddd2166a536e0e38c25b92ddeed5270111b6ed47c8155e4f171dc8bb1782`, 228124 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
