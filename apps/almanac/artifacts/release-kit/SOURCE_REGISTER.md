# Almanac release-material source register

## App Store

The five `artifacts/app-store-previews/source/` PNGs were copied from this app's `docs/release/evidence/ui/` captures. The corresponding scenes are an iPhone 16 Pro English sealed leaf, reflection sheet, and folio detail, plus 13-inch iPad English welcome and today views. The existing evidence register identifies these as iOS simulator debug captures. `preview-spec.json` maps each source to its rendered output; the renderer adds copy and a brand background without changing the in-app UI.

## Google Play

The eight PNGs referenced by `artifacts/google-play-listing/preview-spec.json` were captured from this app running on the Pixel 7 Android API 35 emulator on 2026-10-13. The installed local debug APK was `build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `23f63805645cd4d0ef1b3289fdb8163efb75508c3610f80270d4353f6da8680d`. The emulator display was set to 1080 × 1920 before capture. English scenes show today, selections, reflection, and folio; Simplified Chinese scenes show today, selections, sealed leaf, and folio. Selection and folio content are app-generated local demo state, with no personal text entered. The feature graphics contain no UI capture or device frame.

## Review boundary

All final screenshots and feature graphics were inspected at contact-sheet size; selected phone outputs were also inspected at full resolution. Final images are RGB without alpha. Captures represent debug emulator/simulator runtime, not the future signed release binaries or physical-device behavior. Recheck against the final signed builds before store upload.

The captured debug builds predate the 2026-10-19 source identifier change from `com.example.almanac` to `com.almanac.lite`. The artwork and UI have not been recaptured from a signed build under the new identity.
