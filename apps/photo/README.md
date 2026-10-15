# Jufu

Jufu's iOS build is a bilingual Flutter photo editor. The Android build uses
the separate Flutter project in [`android_app/`](android_app/), which includes
the photo editor and trading interface. The product name is "Jufu" in both
Chinese and English. Static website and iOS legal drafts live in
[`website/`](website/).

The iOS app supports iOS 15.0 and later.

Run `flutter pub get`, `flutter analyze`, and `flutter test` from this directory
for iOS. For Android, run these commands from `android_app/` and build there.
