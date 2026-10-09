# Store Release Kit QA

Target: `/Users/starburst/majia/apps/looters`

Result: FAIL — 6 error(s), 0 warning(s), 13 passed check(s)

## Findings

- **ERROR** `manifest.operator`: Manifest value operator is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **ERROR** `manifest.support_email`: Manifest value support_email is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **ERROR** `manifest.production_domain`: Manifest value production_domain is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **ERROR** `manifest.effective_date`: Manifest value effective_date is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **PASS** `description.limit`: Shared description is 1376/4000 characters — `/Users/starburst/majia/apps/looters/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Apple keywords use 86/100 UTF-8 bytes — `/Users/starburst/majia/apps/looters/artifacts/app-store-listing/keywords-en.txt`
- **PASS** `play_short_description.limit`: Google Play short description is 70/80 characters — `/Users/starburst/majia/apps/looters/artifacts/google-play-listing/short-description-en.txt`
- **ERROR** `website.missing`: Website file is missing: index.html — `/Users/starburst/majia/apps/looters/website/index.html`
- **ERROR** `website.missing`: Website file is missing: privacy.html — `/Users/starburst/majia/apps/looters/website/privacy.html`
- **PASS** `app_store_screenshots.iphone_required`: Found 3 accepted iPhone screenshot(s)
- **PASS** `app_store_screenshots.ipad_required`: Found 1 accepted iPad screenshot(s)
- **PASS** `app_store_screenshots.group`: 3 App Store screenshot(s) at 1206x2622
- **PASS** `app_store_screenshots.group`: 1 App Store screenshot(s) at 2064x2752
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/looters/artifacts/google-play-listing/final/feature-graphic-en.png`
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/looters/artifacts/google-play-listing/final/feature-graphic-zh.png`
- **PASS** `play_screenshots.group_count`: en-US/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: en-US/phone meets the four high-resolution 9:16 or 16:9 recommendation
- **PASS** `play_screenshots.group_count`: zh-CN/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: zh-CN/phone meets the four high-resolution 9:16 or 16:9 recommendation

Passing this report does not prove runtime capture platform or authenticity, visual quality, public hosting, legal review, App Store Connect or Play Console upload, processing, TestFlight or Play testing availability, submission, review, or device behavior.

## Manual visual and source review

- PASS — The four English and four Simplified Chinese Google Play screenshots use real PaceJar UI captured from the Android Pixel 7 API 35 emulator at 1080 × 2400, then rendered to 1080 × 1920 RGB output.
- PASS — The two locales cover four distinct implemented scenes in the same order: pace, recovery options, records, and settings.
- PASS — Full-resolution output and contact sheets were inspected for legibility, cropping, contrast, scene order, localized overlay text, and accidental real-user data. All visible goal, amount, date, and note content is fictional demo data.
- PASS — Both Google Play feature graphics are 1024 × 500 RGB brand artwork with no app UI, device frame, app icon, store badge, ranking, price, or call to action.
- PASS — `app-icon-512.png` reuses the repository's PaceJar icon at 512 × 512 RGBA and is 12,608 bytes, below the 1,024 KB Play limit.
- PASS — The three iPhone and one iPad App Store images were regenerated from their existing real iOS simulator captures after migrating the preview specification to schema version 2, then visually rechecked.
- PASS — A local debug APK built successfully, `flutter analyze --no-pub` reported no issues, and all 44 Flutter tests passed; this is not a signed release App Bundle.
- BLOCKED — Product and privacy HTML cannot be completed without the real operator, support email, production domain, and privacy effective date. No placeholders were inserted.
- NOT RUN — No website was published, no store account was changed, no signed IPA or AAB was built, and no upload or review submission was attempted.
