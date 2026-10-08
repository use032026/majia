# EchoPage website

Static, dependency-free bilingual website and privacy policy for the current
EchoPage `1.0.0` implementation.

## Files

- `index.html`: bilingual product website
- `privacy.html`: bilingual privacy policy
- `styles.css`: responsive shared styles and print rules
- `site.js`: Chinese/English selection, language persistence, metadata, and mobile navigation
- `assets/app-icon.svg`: copy of the current app icon artwork
- `assets/screen-*.png`: copies of the current iPhone App Store preview artwork

The pages work when opened directly or served by a static HTTP server. Use
`?lang=zh` or `?lang=en` to select a language explicitly. Otherwise the site
uses its saved language preference and then the browser language.

For a local preview from this directory:

```sh
python3 -m http.server 8765
```

Then open `http://127.0.0.1:8765/`.

## Product facts reflected here

- no EchoPage account, sign-in, developer backend, ads, analytics, tracking, remote configuration, or IAP
- no runtime permissions and no active networking in the current release implementation
- journal pages, future questions, Echoes, perspective markers, deletion state, and preferences are stored locally by default
- current, pending, and app-managed backup files provide local write/recovery protection rather than developer cloud sync
- clipboard content is created only when the user chooses to copy a complete record
- permanent deletion sanitizes the current installation's app-managed files, not historical operating-system backups
- the website only persists its `zh` or `en` language choice in browser `localStorage`

Recheck these claims whenever dependencies, permissions, storage, account,
network, analytics, advertising, AI, backup, import/export, or sharing behavior
changes.

## Confirm before public publishing

The contact mailbox (`15211857631@163.com`) follows the existing `sdpacket`
website reference. Confirm that it is the monitored privacy/support mailbox for
EchoPage, confirm the final legal operator and product name, choose a stable
HTTPS domain, and compare the policy against the exact signed release archive,
App Store privacy answers, launch regions, and applicable law.

The site intentionally has no App Store download link until a real listing URL
exists. This repository draft is product-specific release material, not legal
advice, and has not been published by this change.
