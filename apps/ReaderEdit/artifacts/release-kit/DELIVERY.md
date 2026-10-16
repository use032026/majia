# ReaderEdit local release-material package

Generated and reviewed on **2026-10-16**, Asia/Shanghai. Target: `/Users/starburst/majia/apps/ReaderEdit`, app version 1.0.0 (1).

**Local draft delivery is complete. Publication readiness remains blocked by user-confirmed missing facts.** No upload, publishing, production build, Store mutation, or submission was authorized or performed.

## Files created

All changes are new files under this app. Existing application source and historical reports were left unchanged. `generated-files.json` gives the complete file-by-file inventory.

| Location | Contents |
| --- | --- |
| `release-kit.yml` | Durable app facts, device support, locales, scene references and unresolved facts. |
| `artifacts/app-store-listing/` | Shared English full description, Apple English keywords. |
| `artifacts/app-store-previews/` | Preview spec, 12 real iOS captures, 12 RGB final screenshots, two contact sheets. |
| `artifacts/google-play-listing/` | English short description, 512px production icon, spec, 8 real Android captures plus XML, system-chrome-only preparation crops, 8 RGB screenshots, 2 feature graphics, two contact sheets. |
| `website/` | Complete English/Chinese product and privacy pages, language selection/metadata script, responsive styling, copied ReaderEdit branding and actual UI images. |
| `website/privacy-en.html`, `website/privacy-zh.html` | Complete static locale policies for a JavaScript-disabled WebView; still local drafts, with no production URL configured. |
| `artifacts/release-kit/` | Facts, source audit, capture provenance/hashes, graphic alt text, asset inventory, browser QA evidence, reports and reproducible demo/material helpers. |

## Copy limits

| Field | Result |
| --- | --- |
| Shared full description | **1,956 / 4,000 characters** |
| Apple keywords | **85 / 100 UTF-8 bytes** |
| Google Play short description | **74 / 80 characters**, one line |

The full description has one shared source; no duplicate Google-only full-description file was created.

## Final images

| Store / device | Locales | Count per locale | Dimensions | Mode |
| --- | --- | ---: | --- | --- |
| App Store iPhone | en-US, zh-Hans | 4 | 1206×2622 | RGB, no alpha |
| App Store 13-inch iPad | en-US, zh-Hans | 2 | 2064×2752 | RGB, no alpha |
| Google Play phone | en-US, zh-CN | 4 | 1080×1920 | RGB, no alpha |
| Google Play feature graphic | English, Simplified Chinese | 1 | 1024×500 | RGB, no alpha |
| Google Play icon | Shared production artwork | 1 | 512×512 | RGBA PNG, below 1 MiB |

Totals: **12 App Store screenshots, 8 Play phone screenshots, 2 feature graphics, 1 Play icon**. All 22 screenshots/feature graphics were inspected individually at original resolution as well as in contact sheets. Scene order: manuscript library → chapter reading → reader-signal queue → before/after comparison. iPad supplies library and queue scenes.

No UI was fabricated. Native platform-specific captures were taken again in iPhone 17 Pro / iPad Pro 13-inch iOS 26.5 simulators and Pixel 7 Android 15 API 35 emulator. Existing local debug binaries were reused. `CAPTURE_README.md` explains demo seeding and Android system-strip crops. `OPEN_ITEMS.md` records the minor current English UI pluralization issue, faithfully retained in screenshots.

## Web and privacy checks

- Both main HTML pages include complete English and Simplified Chinese copy, aligned to the current implementation.
- Browser checks covered 1280×900 desktop and 390×844 mobile viewports; no horizontal overflow was observed. Full-page evidence is in `browser-qa/`.
- Query selection, EN/中文 switches, remembered language, fresh-origin browser-language fallback, document title, description metadata, `<html lang>`, and product/privacy link language were exercised.
- All references across all four HTML files resolve locally. No external font, image, analytics or advertising resource is included.
- Static English and Chinese privacy variants were opened in the browser and contain no scripts. Actual app HTTPS integration was not performed because no approved domain exists.
- Privacy text distinguishes local manuscript data, recovery snapshots, independent sessions, clipboard export, optional online policy requests, file providers, operating-system backups, and website language storage.

## Validation status

[QA_REPORT.md](QA_REPORT.md): **FAIL — 6 errors, 0 warnings, 17 passed checks**.

All six errors are the four unresolved manifest facts plus the missing contact email on the two main pages. The user explicitly confirmed **operator, support email, production domain and effective date are all undecided**. These cannot be resolved without inventing material facts. Pages clearly disclose draft status; there are no fake email/domain placeholders or suppressed checks. See [OPEN_ITEMS.md](OPEN_ITEMS.md).

`SOURCE_AUDIT.md` links current code evidence and the official Apple/Google rules refreshed during this run. `asset-inventory.json`, `capture-manifest.json`, `website-links.json` and `browser-qa/browser-results.json` preserve the mechanical and browser evidence. The script report does not grant legal approval or Store acceptance.

## Not performed

- Website deployment or production/public URL reachability checks.
- App Store Connect / Play Console metadata or media mutation.
- New signed builds, IPA/AAB generation or upload, Store processing.
- TestFlight or Google Play internal testing distribution.
- Review submission, approval or public release.
- Physical-device validation or legal review.
- Application-source fixes, production identifier changes, or policy URL configuration.

The existing app identifiers are still examples and no privacy URL is configured. Separate release work also needs final SDK/privacy inventory, audience/region and rights review, and runtime/device acceptance. These are recorded without treating local artwork validation as release proof.

## Git delivery

On 2026-10-16 the user authorized committing and pushing this local draft package to the repository remote. Git delivery does not publish the website or upload/submit Store materials. All four unresolved facts stay empty; website and configuration updates are deferred until the user confirms them.
