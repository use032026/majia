# Flutter Release Mechanical Preflight

Generated: 2026-10-21T11:21:04+08:00
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
| `warning` | screenshots | Screenshots exist but at least one has alpha or is unreadable. | [{"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/01-onboarding.png", "width": 1080, "height": 2400, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/02-empty-plan.png", "width": 1080, "height": 2400, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/03-supply-devices.png", "width": 1080, "height": 2400, "has_alpha": true}, {"path": "/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runt |
| `pass` | requested_artifacts | All explicitly requested artifacts exist and will be recorded. | {"requested": ["/Users/starburst/Downloads/app-ui-atlas/refqo/build/app/outputs/flutter-apk/app-debug.apk", "/Users/starburst/Downloads/app-ui-atlas/refqo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App"], "missing": []} |

## Artifact hashes

- `/Users/starburst/Downloads/app-ui-atlas/refqo/build/app/outputs/flutter-apk/app-debug.apk` — SHA-256 `1ebdcc00e0c3b88ca60e891fd03829fc270fc4dbc2eb0a7f5b973c977895194b`, 101861436 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App` — SHA-256 `95bb157665aacf48795dfc255fb8276af23d30eb78bc10edc03c728d8c99dff6`, 5885344 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` — SHA-256 `0a535d236e65b5dd107db982321c597451a9fb94092ecdce4bb1d89fc92e945f`, 74128 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/01-onboarding.png` — SHA-256 `e212e958d5d51ec13c33cd93b1a4fd5bb5e400d380a58ad37283c496729288d2`, 177515 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/02-empty-plan.png` — SHA-256 `af753d4db481f5d242adb24dc4e4a2d74a5470640b9e9069fd249d91e930b26b`, 202487 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/03-supply-devices.png` — SHA-256 `660567a8c6483e469bf0353c1a436756007591051bd539ebd2e80147754ad8c8`, 168743 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/04-replace-confirm.png` — SHA-256 `50c8a6d29bb484639d1f203d688ec716daefe3484b957da1a8f60d84a4fbf026`, 209084 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/05-pooled-plan.png` — SHA-256 `54ec4457ac47ac8020437d5d4b62ae809b81153fa14b9e10982de4c244d240a1`, 171135 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/06-sixty-day-plan.png` — SHA-256 `441ed0a8468254976e07bdfa2121f49a1585c7f150bac896d105c4d42efb2378`, 188406 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/07-ledger.png` — SHA-256 `bf5f011b8c6670cb3202b234f8e770299bb523948ac4a271970bf026a7dc3431`, 132892 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/08-settings-zh-dark.png` — SHA-256 `e19c0c54a09e53d9f8431ba08c559b0b9a83778fa515f4b8fb3f1bf65de01dcc`, 272302 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/09-returning-zh-dark.png` — SHA-256 `a366f9742a16adb2a9be08d802e3d18be34d5b6487f1ccd7f29e72f659e39e8c`, 179217 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/10-replay-zh.png` — SHA-256 `ed54726647485c25a3f52de42b987ebc25fd238140e5793a0ae44f5d5ac4eec6`, 186705 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/11-plan-large-text.png` — SHA-256 `20b3bef1ba9b69f50b21b1dd97784ee46565db706903bc9924bd2cd3b71e58c6`, 174142 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/android-api35/12-plan-large-text-end.png` — SHA-256 `089d62ea45bddc7ca57367bc6be2fa34099da0b57ce224ec5153435373f552d5`, 232106 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/01-onboarding.png` — SHA-256 `f13f933d8083cd6f55a6117f78ad49951c5e9e75eb83f8aaec956e2631199e47`, 176466 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/02-empty-plan.png` — SHA-256 `7ce8be1957fdd708fd67ef799ff724be99772f137704bab977238654d76cce24`, 198017 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/03-supply-devices.png` — SHA-256 `560d2cd0b9a762d173c98db11d3d941dd3640a07d7f48eb4c939b9766b05754c`, 202120 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/04-replace-confirm.png` — SHA-256 `a57a445d25e933234d7e5079769f9e2b58939cfab4135c71a88520fe9220bb71`, 230710 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/05-pooled-plan.png` — SHA-256 `da8c6456b0c51c51c26bc9e0ca773f011c154da89123b553186cbde8eefb7f41`, 201831 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/06-sixty-day-plan.png` — SHA-256 `b20077a70c51c07235c8acd8cf9b64d4ae6b24a929626934400814123678f1b7`, 200504 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/07-ledger.png` — SHA-256 `ef01cee2c9909ec371fa18aae4ac9ec339c4bdcbefb8d66eeee697de08e63210`, 151449 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/08-settings-zh-dark.png` — SHA-256 `a3a44dce8a4bf415a05a4eab77e27ab228aa7ade1c0cc972f16649571dbd1fd2`, 229763 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/09-returning-zh-dark.png` — SHA-256 `3b3a345bbb211cc3e101124628f2b3a05fa8d224687e475212b4cdc473797818`, 196172 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/10-replay-zh.png` — SHA-256 `54c67423f0d0d679aed0e804aee93511a2a03f3c68cce134a19a207ff02b5560`, 174698 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/11-plan-large-text.png` — SHA-256 `6e58f33de4ed5e94030805e4f40602b13d3c519ca2a8646612339e3b854e6845`, 259202 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-ipad/12-plan-large-text-end.png` — SHA-256 `611a661d4f042769a0ded44262fa6f041b9f6f478b70a33cdc0b3277c14af48e`, 266557 bytes
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
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/01-onboarding.png` — SHA-256 `a1eeaaab346cdaf1c105b7f97f7fe2f8962a0c59ecd96d265ab5c0e4761d66fc`, 117176 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/02-empty-plan.png` — SHA-256 `6662bc522131d8d7e7d23c94aaa57b33674b99a7a50bb4ca31d705a1d54a7516`, 107492 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/03-supply-devices.png` — SHA-256 `45de60345f05ff1d2b73c010921b742e5f025499afae26118aefef26a9a1343a`, 104946 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/04-replace-confirm.png` — SHA-256 `a5125e0e3a4edb11923b7b67f76fed0392954fbcd6d3e332d834ee6af44c5c8e`, 113322 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/05-pooled-plan.png` — SHA-256 `5b9ffb69840075e204ca7a5c33ccc9831cca21db46a508e5669fd38805152a3c`, 104535 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/06-sixty-day-plan.png` — SHA-256 `e756dfafa97bf1c504d055e590ba2f9595fff7bd07cdceaf1b94b8da5dcff6bd`, 98743 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/07-ledger.png` — SHA-256 `85afbcea8e028f99480d2aecb1643594d6cca379d3f8f1141f0bc34859820ee5`, 97193 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/08-settings-zh-dark.png` — SHA-256 `069fd7d81b06445971412f597e089df6f247b43cce8a30a2020322488a79d7f7`, 97209 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/09-returning-zh-dark.png` — SHA-256 `27fe8f6bf4ca40d47e0f5c862176ac5de4d8a1c8fc3dbc59335b3e7ad99adcbf`, 102769 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/10-replay-zh.png` — SHA-256 `5a29193107fb49feac96c9767741cc79a2b756887cc1ad4a9a897c431b3effe2`, 118116 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/11-plan-large-text.png` — SHA-256 `9993246509e16736f37dd8d32b8f346a497ac789a809a9bc6e9539239318e1fa`, 111519 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/ios-se-final/12-plan-large-text-end.png` — SHA-256 `d43beb317a3e412beddbea351886bd030f86e92709a8e8745baa33cf7b9c2f61`, 124709 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/native/android-cold-onboarding.png` — SHA-256 `538574fcc4b6de0d8db49c826e1d2f6fdd20bfeff6711a9f3cd7e935e625b417`, 181258 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/native/ipad-cold-onboarding.png` — SHA-256 `20fc8b7cce11214f15dd65e89922aeaf496261685ef93d6dfb21c0b7ced2515f`, 203785 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/native/ipad-restore-preview.png` — SHA-256 `445713be9f45ee3ec28af0d3bd0f7deba4d29ca4320663fe8d740b6b2d45ccbc`, 313455 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/native/ipad-restored-success.png` — SHA-256 `cccf95ffe8e800de0b764750e18005fa3d464caae2dffdc03cce5ed0f475c0c9`, 283609 bytes
- `/Users/starburst/Downloads/app-ui-atlas/refqo/docs/release/evidence/runtime/native/ipad-share-fixed.png` — SHA-256 `a447b6f8e78f577b79859d0d75d4ac360cf686c31fbfa7ebdd0348d703b60b21`, 691709 bytes

## Required interpretation

- `review_required` is not an App Store candidate verdict; the Store Reviewer must verify current official requirements and external state.
- This script does not check trademark rights, legal sufficiency, real URL content, App Store Connect metadata, physical devices, upload processing, TestFlight, or App Review.
- This script never uploads, submits, changes certificates, or mutates external accounts.
