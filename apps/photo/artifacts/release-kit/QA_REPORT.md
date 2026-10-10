# Store Release Kit QA

Target: `/Users/starburst/majia/apps/photo`

Result: PASS — 0 error(s), 0 warning(s), 17 passed check(s)

## Findings

- **PASS** `description.limit`: Shared description is 772/4000 characters — `/Users/starburst/majia/apps/photo/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Apple keywords use 81/100 UTF-8 bytes — `/Users/starburst/majia/apps/photo/artifacts/app-store-listing/keywords-en.txt`
- **PASS** `play_short_description.limit`: Google Play short description is 72/80 characters — `/Users/starburst/majia/apps/photo/artifacts/google-play-listing/short-description-en.txt`
- **PASS** `website.locale_content`: index.html contains complete en content — `/Users/starburst/majia/apps/photo/website/index.html`
- **PASS** `website.locale_content`: index.html contains complete zh content — `/Users/starburst/majia/apps/photo/website/index.html`
- **PASS** `website.locale_content`: privacy.html contains complete en content — `/Users/starburst/majia/apps/photo/website/privacy.html`
- **PASS** `website.locale_content`: privacy.html contains complete zh content — `/Users/starburst/majia/apps/photo/website/privacy.html`
- **PASS** `app_store_screenshots.iphone_required`: Found 6 accepted iPhone screenshot(s)
- **PASS** `app_store_screenshots.ipad_required`: Found 5 accepted iPad screenshot(s)
- **PASS** `app_store_screenshots.group`: 6 App Store screenshot(s) at 1206x2622
- **PASS** `app_store_screenshots.group`: 5 App Store screenshot(s) at 2064x2752
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/photo/artifacts/google-play-listing/final/feature-graphic-en.png`
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/photo/artifacts/google-play-listing/final/feature-graphic-zh.png`
- **PASS** `play_screenshots.group_count`: en-US/phone has 6/8 screenshots
- **PASS** `play_screenshots.recommended`: en-US/phone meets the four high-resolution 9:16 or 16:9 recommendation
- **PASS** `play_screenshots.group_count`: zh-CN/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: zh-CN/phone meets the four high-resolution 9:16 or 16:9 recommendation

Passing this report does not prove runtime capture platform or authenticity, visual quality, public hosting, legal review, App Store Connect or Play Console upload, processing, TestFlight or Play testing availability, submission, review, or device behavior.
