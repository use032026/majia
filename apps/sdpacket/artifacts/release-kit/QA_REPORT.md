# Store Release Kit QA

Target: `/Users/starburst/majia/apps/sdpacket`

Result: PASS — 0 error(s), 0 warning(s), 18 passed check(s)

## Findings

- **PASS** `description.limit`: Shared description is 4000/4000 characters — `/Users/starburst/majia/apps/sdpacket/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Apple keywords use 99/100 UTF-8 bytes — `/Users/starburst/majia/apps/sdpacket/artifacts/app-store-listing/keywords-en.txt`
- **PASS** `play_short_description.limit`: Google Play short description is 78/80 characters — `/Users/starburst/majia/apps/sdpacket/artifacts/google-play-listing/short-description-en.txt`
- **PASS** `website.locale_content`: index.html contains complete en content — `/Users/starburst/majia/apps/sdpacket/website/index.html`
- **PASS** `website.locale_content`: index.html contains complete zh content — `/Users/starburst/majia/apps/sdpacket/website/index.html`
- **PASS** `website.locale_content`: privacy.html contains complete en content — `/Users/starburst/majia/apps/sdpacket/website/privacy.html`
- **PASS** `website.locale_content`: privacy.html contains complete zh content — `/Users/starburst/majia/apps/sdpacket/website/privacy.html`
- **PASS** `app_store_screenshots.iphone_required`: Found 6 accepted iPhone screenshot(s)
- **PASS** `app_store_screenshots.ipad_required`: Found 3 accepted iPad screenshot(s)
- **PASS** `app_store_screenshots.group`: 3 App Store screenshot(s) at 1206x2622
- **PASS** `app_store_screenshots.group`: 3 App Store screenshot(s) at 1242x2688
- **PASS** `app_store_screenshots.group`: 3 App Store screenshot(s) at 2732x2048
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/sdpacket/artifacts/google-play-listing/final/feature-graphic-en.png`
- **PASS** `play_feature.valid`: Feature graphic is 1024x500 RGB — `/Users/starburst/majia/apps/sdpacket/artifacts/google-play-listing/final/feature-graphic-zh.png`
- **PASS** `play_screenshots.group_count`: en-US/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: en-US/phone meets the four high-resolution 9:16 or 16:9 recommendation
- **PASS** `play_screenshots.group_count`: zh-CN/phone has 4/8 screenshots
- **PASS** `play_screenshots.recommended`: zh-CN/phone meets the four high-resolution 9:16 or 16:9 recommendation

Passing this report does not prove runtime capture platform or authenticity, visual quality, public hosting, legal review, App Store Connect or Play Console upload, processing, TestFlight or Play testing availability, submission, review, or device behavior.
