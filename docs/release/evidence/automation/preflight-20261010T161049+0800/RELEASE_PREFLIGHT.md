# Flutter Release Mechanical Preflight

Generated: 2026-10-10T16:10:49+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/almanac`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": false} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.almanac", "com.example.almanac.RunnerTests"], "placeholders": ["com.example.almanac"], "expected_bundle_id": "com.example.almanac"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/almanac/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.almanac", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/almanac/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/almanac/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/shared_preferences_foundation.framework/shared_preferences_foundation_privacy.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "PrivacyInfo.xcprivacy", "valid_plist": true}] |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "Flutter.framework", "shared_preferences_foundation.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.almanac", "archive": "com.example.almanac"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `pass` | screenshots | Screenshot PNG dimensions and alpha were inspected. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-en-light-sealed.png", "width": 1206, "height": 2622, "has_alpha": false}, {"path": "/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-en-reflection-sheet.png", "width": 1206, "height": 2622, "has_alpha": false}, {"path": "/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-en-folio-detail.png", "width": 1206, "height": 2622, "has_alpha": false}, {"path": "/Users/starburst/Down |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/almanac/build/app/outputs/bundle/release/app-release.aab", "/Users/starburst/Downloads/app-ui-atlas/almanac/assets/branding/app_icon.svg", "/Users/starburst/Downloads/app-ui-atlas/almanac/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/almanac/build/app/outputs/bundle/release/app-release.aab` — SHA-256 `9d5d2d6fb0ea99dfb257b1c9040e45be2b1cb3d9710fba4edf8e647e1dfd65a3`, 41490483 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/assets/branding/app_icon.svg` — SHA-256 `51c6e0028dcc0dc5851d0b6851d234db027f6cb13aff027c7d7920161cf52795`, 604 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` — SHA-256 `2d9dd46bac9c5f5b5f944b1c8bd9266bf9bb0bd26cb517d314f043a4bcb449d9`, 13442 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `bc2019187c07456410a6dac25691bbaca58da7b9b4239e2163bf14ca195a3158`, 145292433 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `14ed5fe766ef065df2c4c70c8d9cee3be93da81d3940238c768f89ce2e4a3cb0`, 73832 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-en-light-sealed.png` — SHA-256 `4edb3747968f34501e107b05e76e80d137af99833a021f0c3989be6bab40c17c`, 200609 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-en-reflection-sheet.png` — SHA-256 `d3fbc6010abc6f3a2deac15b97dc72ac336310da7fd5d8a07cd39686a96635d0`, 188407 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-en-folio-detail.png` — SHA-256 `eebf2452949698ff97b8f4a92a381142b99fe7f3fdf6db836d1befd5716f0b6e`, 173117 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-zh-dark-settings.png` — SHA-256 `722c4a53a28a96e1d8fb190bf9a0ea44656faade162e2f02e3253882b901cfad`, 189357 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-iphone16pro-zh-dark-sealed.png` — SHA-256 `9792c9e9e57df23a72497162a6b880c1a4cd0b211e1067d904ca5e35750e562e`, 163845 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-ipad11-zh-light-welcome.png` — SHA-256 `892e0e99d06df3a221acc9328ad1547fede8cb55e80c6ff6e23fcf8d6912a5ae`, 128859 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-ipad11-zh-light-today.png` — SHA-256 `7cf0f4ac7662f106fca1e36a7ca29ca01e0b2aba789a80590d1fcc0375f81100`, 158448 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-ipad13-en-light-welcome.png` — SHA-256 `bf125de992cc615ee2d2483ba1b71538565e87dfd3e44de22e207e32e1625567`, 135663 bytes
- `/Users/starburst/Downloads/app-ui-atlas/almanac/docs/release/evidence/store-screenshots/ios-ipad13-en-light-today.png` — SHA-256 `ddb41f97c858da078317e0940ca5b61630bfc972d4dba293b558a380a430cf86`, 200225 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
