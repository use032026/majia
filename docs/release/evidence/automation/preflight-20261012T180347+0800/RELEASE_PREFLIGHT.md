# Flutter Release Mechanical Preflight

Generated: 2026-10-12T18:03:47+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/filepeek`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `warning` | source_traceability | No commit-level Git identity is available. | {"is_repository": true, "root": "/Users/starburst/Downloads/app-ui-atlas/filepeek", "branch": "main", "sha": null, "dirty": true, "status_short": "?? .gitignore\n?? .metadata\n?? README.md\n?? analysis_options.yaml\n?? android/\n?? docs/\n?? ios/\n?? lib/\n?? pubspec.lock\n?? pubspec.yaml\n?? test/"} |
| `blocker` | bundle_identity | Multiple production Bundle IDs found; pass --expected-bundle-id for the intended flavor. | {"identifiers": ["com.example.filepeek", "com.example.filepeek.FilePeekShareExtension", "com.example.filepeek.RunnerTests"], "placeholders": ["com.example.filepeek", "com.example.filepeek.FilePeekShareExtension"], "expected_bundle_id": null} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/filepeek/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.filepeek", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/DKImagePickerController.framework/DKImagePickerController.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/DKPhotoGallery.framework/DKPhotoGallery.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/SDWebImage.framework/SDWebImage.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/SwiftyGif.framework/SwiftyGif.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/file_picker.framework/file_picker_ios |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "DKImagePickerController.framework", "DKPhotoGallery.framework", "Flutter.framework", "SDWebImage.framework", "SwiftyGif.framework", "file_picker.framework", "path_provider_foundation.framework", "receive_sharing_intent.framework", "share_plus.framework"] |
| `blocker` | archive_source_identity | Archive Bundle ID cannot be tied to the selected source configuration. | {"expected": null, "archive": "com.example.filepeek"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `blocker` | screenshots | No PNG runtime/store screenshot evidence was found. |  |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/filepeek/build/app/outputs/flutter-apk/app-debug.apk", "/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/filepeek/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `aab17db8a03662b28727cabd5e0b66caa9804276ab78905cabe8527ec20d8e1a`, 170871150 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive` — SHA-256 `[directory not hashed]`, 160 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `ee7381aafe65939db45fed4cdf7ec703ac2c35f057a9eed681c02261addb344a`, 75120 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
