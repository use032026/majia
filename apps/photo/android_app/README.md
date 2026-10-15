# Jufu Android

This is the Android build root for `apps/photo`. The iOS build root remains
`apps/photo`, with its own `pubspec.yaml`, dependencies, assets, and entrypoint.

The Android app starts in the photo editor on a fresh install. On the Settings
page, hold the Version row for five seconds to save the mode locally and open
the trading interface. The Settings page shows no trading control. On later
starts, the app reads that setting before building either interface, so trading
starts directly.
Clearing app data resets the mode to the photo editor. Reinstall behavior can
depend on Android backup restoration. Trading services are initialized only
after the trading interface is selected.

Build Android from this directory. The shared `Android Package` GitHub Actions
workflow resolves `photo` to this path and uses the existing `PHOTO_ANDROID_*`
signing secrets and `com.lunelle.lite` application ID. The `apps/photo` iOS
release workflow still builds from the parent directory. Android builds from
the parent directory fail with a message pointing to this project.

Before publishing an Android update, ensure its store listing, screenshots,
release notes, privacy disclosures, and review instructions accurately describe
both functions. This project does not update the iOS store materials.
