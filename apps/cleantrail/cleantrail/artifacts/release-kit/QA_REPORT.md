# Store Release Kit QA

Target: `/Users/starburst/majia/apps/cleantrail/cleantrail`

Result: FAIL — 3 error(s), 0 warning(s), 17 passed check(s)

## Findings

- **ERROR** `manifest.operator`: Manifest value operator is missing — `/Users/starburst/majia/apps/cleantrail/cleantrail/release-kit.yml`
- **ERROR** `manifest.production_domain`: Manifest value production_domain is missing — `/Users/starburst/majia/apps/cleantrail/cleantrail/release-kit.yml`
- **ERROR** `manifest.effective_date`: Manifest value effective_date is missing — `/Users/starburst/majia/apps/cleantrail/cleantrail/release-kit.yml`
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

## User confirmation status

On 2026-10-27 the user replied “暂无确定”. Operator, support email, production domain and privacy effective date remain explicitly unconfirmed. The legacy email is a repository reference only; its presence satisfies the current format check but does not confirm it as the ASTFX support address. The privacy policy and metadata remain drafts; publishing/upload is not authorized. See facts-confirmation.json.
