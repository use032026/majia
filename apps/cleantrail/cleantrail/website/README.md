# CleanTrail website

Static, dependency-free bilingual website and privacy policy for the current
CleanTrail 1.0.0 implementation.

## Files

- `index.html`: product website in Simplified Chinese and English
- `privacy.html`: bilingual privacy policy
- `styles.css`: shared responsive styles, including print rules for the policy
- `site.js`: language selection, language-aware internal links, and mobile menu
- `assets/app-icon.png`: copy of the checked-in CleanTrail 1024px app icon
- `assets/app-preview.png`: web-sized crop of a real iOS simulator screenshot

No package installation or build step is required. To preview locally from the
CleanTrail project directory:

```sh
python3 -m http.server 4173 --directory website
```

Then open:

- `http://127.0.0.1:4173/index.html?lang=zh`
- `http://127.0.0.1:4173/index.html?lang=en`
- `http://127.0.0.1:4173/privacy.html?lang=zh`
- `http://127.0.0.1:4173/privacy.html?lang=en`

The language query has priority over the saved website preference. The selected
language is stored only in browser `localStorage` under
`cleantrail-site-language`; the site includes no analytics, advertising, remote
fonts, or third-party JavaScript.

## Product and privacy boundaries

The copy is derived from the current CleanTrail source and release documents:

- CSV, TSV, TXT, and XLSX import through the system file picker
- UTF-8/GBK or worksheet confirmation before inspection
- five local quality checks and user-confirmed repairs
- one app-private project snapshot plus a local recovery backup
- clean/draft CSV and Markdown report export through the system share sheet
- no account, app-operated backend, cloud sync, ads, analytics, or tracking

Support and privacy email: `15211857631@163.com`.

Before production deployment, confirm the final legal operator, monitored email,
domain, HTTPS configuration, and hosting-log policy. A deployed privacy URL should
remain stable, for example:

- `https://<your-domain>/privacy.html?lang=zh`
- `https://<your-domain>/privacy.html?lang=en`

Creating these static files does not publish the website or establish that a
remote URL is reachable.
