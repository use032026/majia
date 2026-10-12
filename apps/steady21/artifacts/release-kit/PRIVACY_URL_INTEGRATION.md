# In-app privacy URL integration check

Checked on 2026-10-12 after the operator supplied the public policy URLs.

- The in-app privacy view selects `https://wowsteady.com/privacy.html?lang=zh` for Chinese and `https://wowsteady.com/privacy.html?lang=en` for English. JavaScript is enabled for the hosted page's language switch. A main-page network or HTTP error switches to the existing local summary.
- Android's main manifest now declares `android.permission.INTERNET`. The merged **release manifest** from `:app:processReleaseMainManifest` contains package `com.steady.lite`, that permission, and launch activity `com.steady.lite.MainActivity`. This Gradle task did not create or sign a release APK/AAB.
- `flutter analyze --no-pub` passed with no issues; `flutter test --no-pub --reporter expanded` passed 33 tests. Android debug APK and iOS Simulator debug builds passed after the URL integration.

The in-app WebView's online rendering and offline fallback have not been exercised on a physical device. The public site still serves older draft wording; see `PUBLIC_URL_CHECK.md`.
