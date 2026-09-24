# PlotProof Lab website

Static, dependency-free product and privacy pages for PlotProof Lab.

## Files

- `index.html` — bilingual product website
- `privacy.html` — bilingual privacy policy
- `styles.css` — shared responsive styles
- `site.js` — language switching, language-aware links, and mobile navigation
- `assets/` — app icon and product screenshots captured from the current app

## Preview locally

From this directory, run any static file server, for example:

```sh
python3 -m http.server 8765
```

Then open:

- `http://127.0.0.1:8765/index.html?lang=zh`
- `http://127.0.0.1:8765/index.html?lang=en`
- `http://127.0.0.1:8765/privacy.html?lang=zh`
- `http://127.0.0.1:8765/privacy.html?lang=en`

The language switch stores only `plotproof-site-language` in browser local storage.

## Publishing checklist

Before publishing, confirm:

1. The operator identity and support email are correct. The current draft uses `15211857631@163.com`, following the existing `sdpacket` site.
2. The final hosting provider and its log-retention terms are reflected in the privacy policy if needed.
3. App Store Connect uses the dedicated privacy URL, such as `https://<domain>/privacy.html?lang=en`, rather than the product homepage.
4. Product claims still match the released build whenever permissions, analytics, lesson hosting, accounts, cloud sync, or other data flows change.
