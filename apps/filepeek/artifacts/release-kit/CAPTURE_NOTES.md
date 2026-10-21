# Capture notes — Fylto (2026-10-21)

## Build and capture provenance at capture time

- Source checkout: `c220cad1f9a05c10f7afdc485abd2a04ff71f759` plus the uncommitted Fylto display-name changes. No business logic was changed for this material refresh. At capture time the Bundle/application ID was `com.example.filerecheck`; the later user-confirmed configuration is recorded below.
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
- At the image-refresh stage, the deterministic gate passed 17 checks and retained six errors from the then-unconfirmed publication facts. Those historical results are superseded by the user-confirmed information below and the regenerated `QA_REPORT.md`.
- Official screenshot and metadata requirements were refreshed on 2026-10-21: [Apple screenshots](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [Apple metadata](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/), [Google Play assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

No website deployment, store metadata/media upload, signed release build, review submission, processing, TestFlight/Play testing distribution or physical-device verification was performed.

## Identity and contact update after capture — 2026-10-21

The user subsequently confirmed operator 独立开发者 (Independent developer), support/privacy email ashcar1986@icloud.com, effective date 2026-10-21 and package identifier `com.fylto.lite`. The iOS target identifiers, Android applicationId/namespace/launcher package, website, policy materials and in-app privacy text have been updated. The domain was initially pending; the subsequent public-URL update below supersedes that material blocker.

The stored runtime captures above retain their original build identity and hashes. This configuration update changes no photographed business flow or displayed Fylto branding. The captures do not establish that a package with the new identifier has been signed, registered, installed or uploaded.

Validation of this update: Flutter analysis reported no issues and all 38 existing tests passed. A new Android Debug APK built successfully; its manifest reports package `com.fylto.lite`, version `1.0.0` / `1`, and launcher `com.fylto.lite.MainActivity`. The iOS project file parsed successfully and all three app configurations plus three test configurations use the new identifier family. No iOS build, installation, signed distribution or account registration was performed for this identity update.

## Public URL update — 2026-10-21

The user confirmed https://fylto1.com, Chinese privacy URL https://fylto1.com/privacy.html?lang=zh and English privacy URL https://fylto1.com/privacy.html?lang=en. All three URLs returned HTTP 200 over HTTPS, and the response bodies matched the local website HTML at verification time. The manifest now records these URLs and https://fylto1.com/#support. The in-app privacy note adds a language-matched full-policy link through the system browser view, retaining the offline note and handling browser-launch failure. This integration does not refresh or change the stored store/website image files.

Validation of the public-URL integration:

- Flutter analysis: no issues. All 38 existing tests plus five local regression tests passed (43 total). The local tests are retained under the ignored `build/privacy-links/tests/` directory and cover current-language routing, preservation of a modified file, browser-launch false/exception retry, duplicate-launch suppression, closing during a pending launch, and narrow-phone layout.
- iOS: a new Debug simulator build with `com.fylto.lite` succeeded and was installed on iPhone 17 Pro / iOS 26.5. Both app languages opened the matching live policy in SFSafariViewController; closing the browser returned to the privacy note, and closing the note returned to the app. Runtime screenshots are local validation artifacts under `build/privacy-links/`, separate from the store images. The temporary task-local DerivedData was removed after installation.
- Android: Debug APK build succeeded after clearing this task's temporary iOS DerivedData to recover disk space. No Android emulator or physical-device policy-link run was performed in this update.
- Release-kit QA: 17 passed checks, zero errors and zero warnings. Neither store console was changed, and no website deployment, signed release build, upload or review submission was performed.
