# ASTFX product website and privacy draft

Current materials for `apps/cleantrail/cleantrail`, generated 2026-10-27. All product and privacy content is present in English and Simplified Chinese.

- `index.html`: ASTFX product page, based on current implementation.
- `privacy.html`: product-specific privacy draft; operator and effective date are still unconfirmed.
- `site.js`: `?lang=en` / `?lang=zh`, stored preference, browser-language fallback, translated title/meta/html language and local links.
- `styles.css`: responsive layout. Desktop and 390px browser checks passed.
- `assets/`: current ASTFX icon and real bilingual iPhone repair-queue captures.

Preview from the app root: `python3 -m http.server 8417 --bind 127.0.0.1 --directory website`.

The pages include no analytics, ads, remote fonts or third-party JavaScript. Only a language preference is stored by the site. Contact copied from the existing project: 15211857631@163.com; monitoring requires confirmation.

Before publication, complete the legal operator, production domain, privacy effective date and hosting practices in `release-kit.yml` and the two policy languages. Nothing has been hosted or uploaded. See `artifacts/release-kit/QA_REPORT.md` and `OPEN_ITEMS.md` for the current generation gate.
