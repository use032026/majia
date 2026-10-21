# Capture notes — Fylto (2026-10-21)

## Current build and capture provenance

- Source checkout: `c220cad1f9a05c10f7afdc485abd2a04ff71f759` plus the uncommitted Fylto display-name changes. No business logic was changed for this material refresh. Bundle/application ID remains `com.example.filerecheck`.
- iOS: fresh Xcode Debug simulator build, code signing disabled, installed on iPhone 17 Pro and iPad Pro 13-inch (M5), both iOS 26.5. Raw captures are 1206 × 2622 and 2064 × 2752. Captured with `simctl io screenshot`; the temporary task-local DerivedData is removed after capture.
- Android: fresh Flutter Debug APK, installed on Pixel 7 API 35 emulator with a 1080 × 1920 capture display. Raw captures use Android screencap. English and Simplified Chinese scenes were captured separately.
- Review files: `docs/release/review_samples/check.json`, `compare.json` and `check.csv`. These are repository sample data, not personal files.
- To avoid unstable native file-picker automation, the debugger loaded those sample bytes into the app's existing document model and selected the existing home, JSON, CSV, comparison, report and cell-editor states. Parsing, comparison, report generation and UI rendering use the unchanged application implementation. This is runtime screenshot evidence; it does not independently validate the operating-system picker, onboarding persistence, exports, or a physical device.
- No UI text was painted over an old screenshot. All source screenshots were replaced by current runtime captures. Local capture helpers and logs are under ignored `build/fylto-materials/` and are not app entrypoints or release code.

## Delivered images

- App Store: five English iPhone images at 1206 × 2622 and two English iPad images at 2064 × 2752, all RGB without alpha. Scenes: home, JSON, CSV, JSON comparison and report; iPad shows JSON and CSV.
- Google Play: four English and four Simplified Chinese phone images at 1080 × 1920, all RGB without alpha. Scenes: home, JSON, CSV and report.
- Google Play feature graphics: English and Simplified Chinese, 1024 × 500 RGB, using the Fylto brand and factual headline without a UI screenshot or device frame.
- Website: `assets/app-preview.png` is the new English iPhone JSON capture; `assets/app-preview-zh-ios.png` is the new Chinese iPhone CSV capture. Both are 1206 × 2622. The existing icon has no name text and is unchanged.
- Internal UI QA: iPhone CSV editor with and without software keyboard, plus iPad CSV editor, were also recaptured.
- Rendering uses the existing release-kit renderer and current Fylto preview specifications. Captures are converted to RGB and placed with factual headlines and decorative backgrounds; functional UI is not retouched.
- Visual review covered every final image through contact sheets, plus full-resolution report, CSV and website samples. A CSV scene captured during a route transition was replaced and rerendered after review.
- `name-audit.json` records OCR checks and SHA-256 hashes for 44 current image files. No FileRecheck or FilePeek branding was recognized. Unlettered icons and an obscured title in the keyboard QA scene are expected exceptions to recognizing Fylto itself.

## Listing and website checks

- Shared English description: 1353 / 4000 characters.
- Apple keywords: 96 / 100 UTF-8 bytes. The app name is intentionally not repeated in the keyword field.
- Google Play English short description: 77 / 80 characters.
- The local product page and privacy page were opened in the browser and switched between English and Chinese; titles, links, text and active product images followed the language.
- `app-facts.json` and `QA_REPORT.md` were refreshed. The deterministic gate passes 17 checks and retains six errors caused by the four previously unconfirmed operator/contact/domain/effective-date facts and the missing website/privacy contact email.
- Official screenshot and metadata requirements were refreshed on 2026-10-21: [Apple screenshots](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [Apple metadata](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [Google Play assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

No website deployment, store metadata/media upload, signed release build, review submission, processing, TestFlight/Play testing distribution or physical-device verification was performed.
