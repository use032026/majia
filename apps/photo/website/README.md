# Jufu website

Static, dependency-free website and legal pages for the current Jufu 1.0
implementation.

## Files

- `index.html`: bilingual product website
- `privacy.html`: bilingual privacy policy
- `terms.html`: bilingual terms of use / user agreement
- `styles.css`: shared responsive and print styles
- `site.js`: Chinese/English selection, language persistence, and mobile navigation
- `assets/app-icon.png`: copy of the current production app icon

The pages work when opened directly and when served by a static HTTP server.
Use `?lang=zh` or `?lang=en` to select a language explicitly. Otherwise the
site uses its saved language preference and then the browser language.

## Product facts reflected in this draft

- no Jufu account, sign-in, developer cloud library, ads, or analytics SDK
- the user explicitly selects one image from the system photo interface
- the current primary flow does not use the camera
- crop, effects, brightness, and text watermark rendering happen on device
- the generated PNG is written to the system photo library only after the user
  taps **Save to Photos**
- only the app language preference is intentionally persisted by the Flutter
  code; the website separately stores `zh` or `en` in browser localStorage

Recheck these claims whenever dependencies, permissions, data flows, saving,
cloud features, analytics, advertising, or account support changes.

## Required before public publishing

The legal pages currently show:

- operator: `Jufu独立开发者` (confirmed)
- support/privacy email: `djl13333995679@163.com`
- privacy policy effective date: `2026-09-18` (confirmed)

Then obtain appropriate legal review for the release regions. These pages are
product-specific compliance drafts, not legal advice.

## App integration

The app's settings page in `lib/app_settings.dart` opens the published HTTPS
pages in the external browser, using `lang=zh` or `lang=en` to match the app's
current language (including the device language when following the system):

- privacy: `https://lunelleglobal.com/privacy.html?lang=zh` or `?lang=en`
- terms: `https://lunelleglobal.com/terms.html?lang=zh` or `?lang=en`

These links retain the existing domain so the app does not point to an
unconfigured address. Update the host and deploy the renamed pages when the
new Jufu domain is ready.

Keep the released binary, store privacy disclosures, permission descriptions,
and these pages in sync.
