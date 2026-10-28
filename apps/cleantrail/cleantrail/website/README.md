# ASTFX product website and privacy policy

Current materials for `apps/cleantrail/cleantrail`, updated 2026-10-28. All product and privacy content is present in English and Simplified Chinese.

- `index.html`: ASTFX product page, based on current implementation.
- `privacy.html`: product-specific privacy policy; effective 2026-10-28, operated by an independent developer.
- `site.js`: `?lang=en` / `?lang=zh`, stored preference, browser-language fallback, translated title/meta/html language and local links.
- `styles.css`: responsive layout. Desktop and 390px layout checks passed on 2026-10-27. The 2026-10-28 facts update passed static checks and desktop browser checks of both product/policy languages, contact links, effective date, and language switching; mobile layout was not rerun.
- `assets/`: current ASTFX icon and real bilingual iPhone repair-queue captures.

Preview from the app root: `python3 -m http.server 8417 --bind 127.0.0.1 --directory website`.

The pages include no analytics, ads, remote fonts or third-party JavaScript. Only a language preference is stored by the site. The user confirmed the operator as 独立开发者 (Independent developer), support/privacy contact as evwascr0317@icloud.com, and policy effective date as 2026-10-28.

The user confirmed the production domain as [https://astfx1.com](https://astfx1.com), with privacy pages in [Simplified Chinese](https://astfx1.com/privacy.html?lang=zh) and [English](https://astfx1.com/privacy.html?lang=en). The app defaults to `https://astfx1.com/privacy.html` and sets the language query parameter from its current language; a build-time `PRIVACY_POLICY_URL` override remains supported. Public reachability is checked separately from these confirmed configuration values. Hosting provider and log practices remain pending. See `artifacts/release-kit/QA_REPORT.md` and `OPEN_ITEMS.md` for the current generation gate.
