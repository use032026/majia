# Store Release Kit QA

Target: `/Users/starburst/majia/apps/almanac`

Result: PASS — 0 error(s), 0 warning(s), 17 passed check(s)

## Findings

- **PASS** `description.limit`: Shared description is 920/4000 characters — `/Users/starburst/majia/apps/almanac/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Apple keywords use 74/100 UTF-8 bytes — `/Users/starburst/majia/apps/almanac/artifacts/app-store-listing/keywords-en.txt`
- **PASS** `play_short_description.limit`: Google Play short description is 68/80 characters — `/Users/starburst/majia/apps/almanac/artifacts/google-play-listing/short-description-en.txt`
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
