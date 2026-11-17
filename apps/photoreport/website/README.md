# JOVFX website

Dependency-free static website for JOVFX on iPhone, iPad, and Android.

## Files

- `index.html`: bilingual product website
- `privacy.html`: bilingual privacy policy
- `styles.css`: shared responsive and print styles
- `site.js`: language preference, language-aware links, and mobile navigation
- `assets/app-icon.png`: JOVFX app icon
- `assets/og.png`: social preview card
- `assets/workspace-en.webp`, `assets/workspace-zh.webp`: current JOVFX workspace captures in English on iPhone and Simplified Chinese on Android

## Local preview

Serve this directory with any static HTTP server and open `index.html`.
Use `?lang=en` or `?lang=zh` to preview a specific language. The language
switch also saves your selection in browser storage.

The product page and privacy policy both list the independent developer and the
public contact email `PadonSolmonson469@outlook.com`.

## Production links

- [JOVFX website](https://jovfx1.com/)
- [Support](https://jovfx1.com/?lang=en#support)
- [English privacy policy](https://jovfx1.com/privacy.html?lang=en)
- [Simplified Chinese privacy policy](https://jovfx1.com/privacy.html?lang=zh)

## Publication checklist

1. Verify how the production host handles request logs and update the disclosure
   in section 7 in both languages.
2. Verify the public links and Open Graph image after deploying the site files.
3. Recheck the policy whenever app permissions, SDKs, storage, export, sync,
   account, or analytics behavior changes.
4. Have the final policy reviewed for the countries and regions where the app
   will be distributed. This repository draft is product-specific compliance
   content, not legal advice.
