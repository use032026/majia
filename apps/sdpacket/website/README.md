# KIFXPRO website

Static, dependency-free official website and privacy policy for the current
KIFXPRO `0.1.0` implementation.

## Files

- `index.html`: bilingual product website
- `privacy.html`: bilingual privacy policy
- `styles.css`: shared responsive and print styles
- `site.js`: Chinese/English selection, language persistence, and mobile navigation
- `assets/app-icon.png`: copy of the current production app icon

The pages work when opened directly and when served by a static HTTP server.
Use `?lang=zh` or `?lang=en` to select a language explicitly. Otherwise the
site uses its saved language preference and then the browser language.

## Product facts reflected in this draft

- no KIFXPRO account, sign-in, developer cloud, ads, analytics SDK, or third-party AI
- projects, box records, notes, item lists, statuses, and managed photos are stored locally by default
- camera, photo picker, microphone, speech recognition, and scanner access are user initiated
- speech recognition may be handled on device or by the operating-system speech provider
- QR labels contain only a format version, project ID, box ID, and readable box code
- exports, backups, printing, and sharing happen only after the user starts the action
- the website only persists its `zh` or `en` language choice in browser localStorage

Recheck these claims whenever dependencies, permissions, storage, account,
network, analytics, advertising, AI, backup, or sharing behavior changes.

## Required before public publishing

This draft currently shows:

- operator: `KIFXPRO 独立开发者`
- support/privacy email: `15211857631@163.com`
- policy update date: `2026-09-22`

Confirm the legal operator and mailbox, choose a production website URL, and
obtain appropriate legal review for the release regions. This page is a
product-specific compliance draft, not legal advice.

## App integration

The app settings screen uses fixed, language-aware public links:

- Chinese privacy: `https://kifxpro.com/privacy.html?lang=zh`
- English privacy: `https://kifxpro.com/index.html?lang=en`
- support email: `15211857631@163.com`

If a remote privacy page cannot be opened, the app shows its complete built-in
privacy notice. If no mail app is available, it shows the support address for
manual use.
