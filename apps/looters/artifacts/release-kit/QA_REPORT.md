# App Store Release Kit QA

Target: `/Users/starburst/majia/apps/looters`

Result: FAIL — 6 error(s), 0 warning(s), 6 passed check(s)

## Findings

- **ERROR** `manifest.operator`: Manifest value operator is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **ERROR** `manifest.support_email`: Manifest value support_email is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **ERROR** `manifest.production_domain`: Manifest value production_domain is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **ERROR** `manifest.effective_date`: Manifest value effective_date is missing — `/Users/starburst/majia/apps/looters/release-kit.yml`
- **PASS** `description.limit`: Description is 1376/4000 characters — `/Users/starburst/majia/apps/looters/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Keywords use 86/100 UTF-8 bytes — `/Users/starburst/majia/apps/looters/artifacts/app-store-listing/keywords-en.txt`
- **ERROR** `website.missing`: Website file is missing: index.html — `/Users/starburst/majia/apps/looters/website/index.html`
- **ERROR** `website.missing`: Website file is missing: privacy.html — `/Users/starburst/majia/apps/looters/website/privacy.html`
- **PASS** `screenshots.iphone_required`: Found 3 accepted iPhone screenshot(s)
- **PASS** `screenshots.ipad_required`: Found 1 accepted iPad screenshot(s)
- **PASS** `screenshots.group`: 3 screenshot(s) at 1206x2622
- **PASS** `screenshots.group`: 1 screenshot(s) at 2064x2752

Passing this report does not prove runtime capture authenticity, visual quality, public hosting, legal review, App Store upload, processing, TestFlight availability, submission, review, or device behavior.
