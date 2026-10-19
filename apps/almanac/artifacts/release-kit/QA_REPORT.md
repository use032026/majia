# Store Release Kit QA

Target: `/Users/starburst/majia/apps/almanac`

Result: PASS — 0 error(s), 0 warning(s), 17 passed check(s)

## Findings

- **PASS** `description.limit`: Shared description is 1411/4000 characters — `/Users/starburst/majia/apps/almanac/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Apple keywords use 94/100 UTF-8 bytes — `/Users/starburst/majia/apps/almanac/artifacts/app-store-listing/keywords-en.txt`
- **PASS** `play_short_description.limit`: Google Play short description is 66/80 characters — `/Users/starburst/majia/apps/almanac/artifacts/google-play-listing/short-description-en.txt`
- **PASS** `website.locale_content`: index.html contains complete en content — `/Users/starburst/majia/apps/almanac/website/index.html`
- **PASS** `website.locale_content`: index.html contains complete zh content — `/Users/starburst/majia/apps/almanac/website/index.html`
- **PASS** `website.locale_content`: privacy.html contains complete en content — `/Users/starburst/majia/apps/almanac/website/privacy.html`
- **PASS** `website.locale_content`: privacy.html contains complete zh content — `/Users/starburst/majia/apps/almanac/website/privacy.html`
- **PASS** `app_store_screenshots.iphone_required`: Found 3 accepted iPhone screenshot(s)
- **PASS** `app_store_screenshots.ipad_required`: Found 2 accepted iPad screenshot(s)
- **PASS** `app_store_screenshots.group`: 3 App Store screenshot(s) at 1206x2622
- **PASS** `app_store_screenshots.group`: 2 App Store screenshot(s) at 2064x2752
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/almanac/artifacts/google-play-listing/final/feature-graphic-en.png`
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/almanac/artifacts/google-play-listing/final/feature-graphic-zh.png`
- **PASS** `play_screenshots.group_count`: en-US/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: en-US/phone meets the four high-resolution 9:16 or 16:9 recommendation
- **PASS** `play_screenshots.group_count`: zh-CN/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: zh-CN/phone meets the four high-resolution 9:16 or 16:9 recommendation

Passing this report does not prove runtime capture platform or authenticity, visual quality, public hosting, legal review, App Store Connect or Play Console upload, processing, TestFlight or Play testing availability, submission, review, or device behavior.

## Deynu refresh evidence — 2026-10-19

The standard gate above passed all 17 checks. The following additional checks and manual review were performed for this refresh:

- App Store name: 5/30 characters; subtitle: 26/30; promotional text: 137/170. Play name: 5/30. Shared full description: 1411/4000; Apple keywords: 94/100 UTF-8 bytes; Play short description: 66/80. Counts exclude the trailing file newline.
- All 13 source screenshots were freshly captured from the current native runtime: 3 iPhone, 2 iPad, and 4 English plus 4 Simplified Chinese Android scenes. Source methods, demo state and hashes are recorded in `SOURCE_REGISTER.md` and `capture-provenance.json`.
- All 15 final screenshots/feature graphics were regenerated, inspected on the four contact sheets, and checked at representative full resolution. Text fits, core choices and controls are legible, the scenes match the implemented workflow, and no personal user records were used.
- All 15 final images passed Apple Vision OCR for Deynu branding and absence of the previous wordmarks. See `branding-checks.json`. OCR complements the manual review; it is not a guarantee of recognizing every pixel of text.
- All 15 final images are RGB PNG without alpha, at their specified sizes. The 1024-pixel App Store icon matches the native production icon exactly; the 512-pixel Play icon is the existing RGBA derivative without a name wordmark.
- File references in both artwork specifications and all Play alternative-text rows resolve to the current assets. The old Chinese sealed-scene filename was removed in favor of `03-reflect.png`.
- Product and privacy pages were opened locally and switched between English and Chinese. Titles, visible Deynu copy and navigation follow the selected language. Both updated website screenshot files loaded successfully at 1206 × 2622.
- The iOS simulator build and Android debug build succeeded. The built app identifies itself as Deynu 1.0.0 (1), `com.almanac.lite`. After Android capture, the normal debug APK was rebuilt from `lib/main.dart`; the capture helper remains outside production source and the material archive.
- Protected production source, native settings and website files match the snapshot taken at the start of this materials pass. Earlier rename/website changes are preserved.

Machine-readable asset and metadata checks are in `material-checks.json`. The local delivery map is `DELIVERY.md`.

## Official specifications checked

- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Apple platform version metadata](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Google Play preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Google Play store listing fields](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en-EN)

## Release boundary

This is a local material-generation pass. No public deployment, App Store Connect or Play Console mutation, signed IPA/AAB, store upload/processing, testing distribution, review submission or physical-device verification was performed. Legal/operator and final signed-build/privacy checks remain recorded in `OPEN_ITEMS.md`.
