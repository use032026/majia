# Flutter Release Mechanical Preflight

Generated: 2026-10-12T18:47:17+08:00
Project: `/Users/starburst/Downloads/app-ui-atlas/filepeek`
Mechanical verdict: `blocked`

| Status | Check | Summary | Evidence |
| --- | --- | --- | --- |
| `pass` | source_traceability | Git source identity is available. | {"is_repository": true, "root": "/Users/starburst/Downloads/app-ui-atlas/filepeek", "branch": "main", "sha": "e728d35f6a17fe59a71d070809427f502f60ed4b", "dirty": true, "status_short": "?? docs/factory/\n?? docs/release/APP_STORE_PREFLIGHT.md\n?? docs/release/EVIDENCE_REGISTER.md\n?? docs/release/FUNCTIONAL_REVIEW.md\n?? docs/release/GAP_BACKLOG.md\n?? docs/release/PRIVACY_POLICY_DRAFT.md\n?? docs/release/REVIEW_NOTES_DRAFT.md\n?? docs/release/evidence/"} |
| `blocker` | bundle_identity | Missing or placeholder iOS Bundle ID. | {"identifiers": ["com.example.filepeek", "com.example.filepeek.FilePeekShareExtension", "com.example.filepeek.RunnerTests"], "placeholders": ["com.example.filepeek", "com.example.filepeek.FilePeekShareExtension"], "expected_bundle_id": "com.example.filepeek"} |
| `blocker` | privacy_url | Privacy Url: not provided. |  |
| `blocker` | support_url | Support Url: not provided. |  |
| `pass` | preview_labels | No common MVP/prototype/demo wording was found in the scanned app-facing source types. | {"hits": [], "scanned_suffixes": [".arb", ".dart", ".java", ".json", ".kt", ".m", ".mm", ".plist", ".strings", ".swift", ".txt", ".xcstrings", ".xml", ".yaml", ".yml"]} |
| `pass` | app_icon | 1024px AppIcon exists without alpha. | {"path": "/Users/starburst/Downloads/app-ui-atlas/filepeek/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "width": 1024, "height": 1024, "has_alpha": false} |
| `pass` | archive_info | Archive Info.plist was parsed. | {"CFBundleIdentifier": "com.example.filepeek", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1", "MinimumOSVersion": "15.0", "DTXcode": "2650", "DTSDKName": "iphoneos26.5", "CFBundleDevelopmentRegion": "en"} |
| `blocker` | code_signing_presence | Archive lacks a validating signature or embedded provisioning profile. | {"verify_return_code": 1, "verify_output": "/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all\nIn architecture: arm64", "details": "/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app: code object is not signed at all", "embedded_mobileprovision": false} |
| `pass` | privacy_manifests | Privacy manifests were found and parsed. | [{"path": "Frameworks/DKImagePickerController.framework/DKImagePickerController.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/DKPhotoGallery.framework/DKPhotoGallery.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/Flutter.framework/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/SDWebImage.framework/SDWebImage.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/SwiftyGif.framework/SwiftyGif.bundle/PrivacyInfo.xcprivacy", "valid_plist": true}, {"path": "Frameworks/file_picker.framework/file_picker_ios |
| `info` | archive_dependencies | Recorded embedded archive frameworks for reviewer inspection. | ["App.framework", "DKImagePickerController.framework", "DKPhotoGallery.framework", "Flutter.framework", "SDWebImage.framework", "SwiftyGif.framework", "file_picker.framework", "path_provider_foundation.framework", "receive_sharing_intent.framework", "share_plus.framework"] |
| `pass` | archive_source_identity | Archive Bundle ID matches the selected source configuration. | {"expected": "com.example.filepeek", "archive": "com.example.filepeek"} |
| `pass` | archive_source_version | Archive version and build number match the expected Flutter source values. | {"expected_version": "1.0.0", "expected_build_number": "1", "archive_version": "1.0.0", "archive_build_number": "1"} |
| `warning` | screenshots | Screenshots exist but at least one has alpha or is unreadable. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-csv-share.png", "width": 1080, "height": 1920, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-json-share.png", "width": 1080, "height": 1920, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-report-share.png", "width": 1080, "height": 1920, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runt |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/filepeek/build/app/outputs/flutter-apk/app-debug.apk"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/filepeek/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `278ed5ec8caa39dadab23fb2698b4ea9cf0c49db96caa34e9333ff77407e33e4`, 170874512 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `de6337d19dcd0708709bf5f6cc74ae144a00d71744efdd46f98163f9e32b28ad`, 96528 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-csv-share.png` — SHA-256 `ea1abce6b1d3a4c3526d463c4ad47877e1e9f6b73ab4b11bf50dee9c28edaf9a`, 118583 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-json-share.png` — SHA-256 `eb1711e582aa314b37d66023f1f7f23a63404899f3dbf03fe4bba87b3ac614c6`, 131805 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-report-share.png` — SHA-256 `82bbb2a5df4aa6209be0b1f7016389f49c0549d493c52494ed30ac14bca4a21e`, 138087 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/android-api35-txt-share.png` — SHA-256 `ff8a506d6711904e6ae70039036169f25e0c70166cf421c8607e453ea421ee46`, 103459 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/ios-share-before-baseline.png` — SHA-256 `d3b6628adbcffe3d2657df3562c73818e2472885b8be36c2716aed396ffd9c9a`, 201721 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/ios-share-cold-start-import.png` — SHA-256 `ea84d3362327f63e76f098b7988296c1b1a35c84d7fc69b327119a40ca3964f5`, 237766 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/ios-share-resume-import-space-name.png` — SHA-256 `ca67360fbca6302ce5d26b4e7fcd1301bd29cdc59246f8a46c698b69a80ebc9b`, 215384 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/ios-share-saved-open-app.png` — SHA-256 `da12d4641e59e3e7052912e4733ebc76b1e4e33e71ccaeac803861951e6ec686`, 868581 bytes
- `/Users/starburst/Downloads/app-ui-atlas/filepeek/docs/release/evidence/runtime/ios26-iphone17pro-app.png` — SHA-256 `c5ad94e3d4832715029bf47dddf6c25d682a869ff94e02ced06e609cec89d18c`, 216968 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
