# App Store Release Kit QA

Target: `/Users/starburst/majia/apps/Somniloquy`

Result: FAIL — 8 error(s), 0 warning(s), 6 passed check(s)

## Findings

- **ERROR** `manifest.operator`: Manifest value operator is missing — `/Users/starburst/majia/apps/Somniloquy/release-kit.yml`
- **ERROR** `manifest.support_email`: Manifest value support_email is missing — `/Users/starburst/majia/apps/Somniloquy/release-kit.yml`
- **ERROR** `manifest.production_domain`: Manifest value production_domain is missing — `/Users/starburst/majia/apps/Somniloquy/release-kit.yml`
- **ERROR** `manifest.effective_date`: Manifest value effective_date is missing — `/Users/starburst/majia/apps/Somniloquy/release-kit.yml`
- **PASS** `description.limit`: Description is 1395/4000 characters — `/Users/starburst/majia/apps/Somniloquy/artifacts/app-store-listing/description-en.txt`
- **PASS** `keywords.limit`: Keywords use 94/100 UTF-8 bytes — `/Users/starburst/majia/apps/Somniloquy/artifacts/app-store-listing/keywords-en.txt`
- **ERROR** `website.placeholder`: Unresolved template marker: [[SUPPORT_EMAIL]] — `/Users/starburst/majia/apps/Somniloquy/website/index.html`
- **ERROR** `website.placeholder`: Unresolved template marker: [[SUPPORT_EMAIL]] — `/Users/starburst/majia/apps/Somniloquy/website/privacy.html`
- **ERROR** `website.contact`: Product website has no support email — `/Users/starburst/majia/apps/Somniloquy/website/index.html`
- **ERROR** `privacy.contact`: Privacy policy has no contact email — `/Users/starburst/majia/apps/Somniloquy/website/privacy.html`
- **PASS** `screenshots.iphone_required`: Found 4 accepted iPhone screenshot(s)
- **PASS** `screenshots.ipad_required`: Found 4 accepted iPad screenshot(s)
- **PASS** `screenshots.group`: 4 screenshot(s) at 1206x2622
- **PASS** `screenshots.group`: 4 screenshot(s) at 2064x2752

Passing this report does not prove runtime capture authenticity, visual quality, public hosting, legal review, App Store upload, processing, TestFlight availability, submission, review, or device behavior.
