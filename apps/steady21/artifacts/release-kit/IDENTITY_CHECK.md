# App identity check

Checked on 2026-10-12 after the operator specified `com.steady.lite` for both platforms.

| Layer | Result |
| --- | --- |
| iOS Xcode Runner configurations | `PRODUCT_BUNDLE_IDENTIFIER = com.steady.lite` in all Runner configurations; RunnerTests uses `com.steady.lite.RunnerTests`. |
| iOS unsigned Simulator debug build | `flutter build ios --simulator --debug --no-pub` passed; `Runner.app/Info.plist` reports `CFBundleIdentifier = com.steady.lite`. |
| Android source | Gradle namespace and application ID are `com.steady.lite`; `MainActivity.kt` is under `com/steady/lite/` with the matching Kotlin package. The main manifest's relative `.MainActivity` resolves under the new namespace. |
| Android debug APK | `flutter build apk --debug --no-pub` passed; AAPT reports package `com.steady.lite` and launcher `com.steady.lite.MainActivity`. |
| Repository Android cloud-package registration | `.github/android-packages.json` maps `steady21` to `com.steady.lite`. |

These checks do not prove a signed distribution build, developer-account registration, provisioning profile, App Store Connect or Play Console acceptance, or upload.
