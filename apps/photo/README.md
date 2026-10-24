# Jufu

Jufu's iOS build is a bilingual Flutter photo editor. The Android build uses
the separate Flutter project in [`android_app/`](android_app/), which includes
the photo editor and trading interface. The product name is "Jufu" in both
Chinese and English. Static website and iOS legal drafts live in
[`website/`](website/).

The iOS app supports iOS 15.0 and later.

Run `flutter pub get`, `flutter analyze`, and `flutter test` from this directory
for iOS. For Android, run these commands from `android_app/` and build there.

## Online privacy policy

The iOS privacy-policy button loads the existing `https://lunelleglobal.com/privacy.html?lang=zh|en` address. Terms of Use keeps its external-browser route, and photo saving keeps its existing native channel. The separate Android project is unchanged.

On an explicit tap, the app requests the actual policy through an ephemeral `URLSession` and displays that response in its own nonpersistent `WKWebView`. First-network authorization is handled by iOS when required by the device and its current permission state. Loading failures offer retry, copy address, and close; failure to present the native page uses the existing Flutter failure message. No startup request or unrelated probe is added.
