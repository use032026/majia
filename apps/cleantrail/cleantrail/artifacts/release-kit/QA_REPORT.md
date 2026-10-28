# Store Release Kit QA

Target: `/Users/starburst/majia/apps/cleantrail/cleantrail`

Result: PASS — 0 error(s), 0 warning(s), 17 passed check(s)

## Findings

- **PASS** `description.limit`: Shared description is 2464/4000 characters — `/Users/starburst/majia/apps/cleantrail/cleantrail/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Apple keywords use 94/100 UTF-8 bytes — `/Users/starburst/majia/apps/cleantrail/cleantrail/artifacts/app-store-listing/keywords-en.txt`
- **PASS** `play_short_description.limit`: Google Play short description is 78/80 characters — `/Users/starburst/majia/apps/cleantrail/cleantrail/artifacts/google-play-listing/short-description-en.txt`
- **PASS** `website.locale_content`: index.html contains complete en content — `/Users/starburst/majia/apps/cleantrail/cleantrail/website/index.html`
- **PASS** `website.locale_content`: index.html contains complete zh content — `/Users/starburst/majia/apps/cleantrail/cleantrail/website/index.html`
- **PASS** `website.locale_content`: privacy.html contains complete en content — `/Users/starburst/majia/apps/cleantrail/cleantrail/website/privacy.html`
- **PASS** `website.locale_content`: privacy.html contains complete zh content — `/Users/starburst/majia/apps/cleantrail/cleantrail/website/privacy.html`
- **PASS** `app_store_screenshots.iphone_required`: Found 8 accepted iPhone screenshot(s)
- **PASS** `app_store_screenshots.ipad_required`: Found 8 accepted iPad screenshot(s)
- **PASS** `app_store_screenshots.group`: 8 App Store screenshot(s) at 1206x2622
- **PASS** `app_store_screenshots.group`: 8 App Store screenshot(s) at 2064x2752
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/cleantrail/cleantrail/artifacts/google-play-listing/final/feature-graphic-en.png`
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/cleantrail/cleantrail/artifacts/google-play-listing/final/feature-graphic-zh.png`
- **PASS** `play_screenshots.group_count`: en-US/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: en-US/phone meets the four high-resolution 9:16 or 16:9 recommendation
- **PASS** `play_screenshots.group_count`: zh-CN/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: zh-CN/phone meets the four high-resolution 9:16 or 16:9 recommendation

Passing this report does not prove runtime capture platform or authenticity, visual quality, public hosting, legal review, App Store Connect or Play Console upload, processing, TestFlight or Play testing availability, submission, review, or device behavior.

## Production URL update — 2026-10-28

The user confirmed https://astfx1.com and its Chinese/English privacy URLs. These are saved in release-kit.yml and store-metadata-draft.json. The app defaults to https://astfx1.com/privacy.html and adds lang=zh or lang=en from its current language; PRIVACY_POLICY_URL remains an override.

20 focused unit/widget tests passed and Flutter analysis passed. Public website and both policy URLs returned HTTP 200 with normal TLS verification; a desktop browser displayed the matching policy languages, contact and effective date. The live policy still has an old pending-domain statement; the local bilingual website source is corrected and has not been republished by this task. Native app build/device behavior and store submission were not validated.
