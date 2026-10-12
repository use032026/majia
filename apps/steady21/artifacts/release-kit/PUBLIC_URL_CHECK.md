# Public website and privacy URL check

Checked again on 2026-10-12 after the operator confirmed deployment. The hosted product page, privacy policy, JavaScript, and stylesheet returned HTTPS 200 and matched the corresponding local `website/` files byte for byte. No store upload was performed in this run.

| URL | Reachability | Browser check |
| --- | --- | --- |
| `https://wowsteady.com/privacy.html?lang=zh` | HTTPS 200, `text/html` | Chinese title, 2026-10-12 effective date, full Chinese policy and support email visible. |
| `https://wowsteady.com/privacy.html?lang=en` | HTTPS 200, `text/html` | English title, 12 October 2026 effective date, full English policy and support email visible. |
| `https://wowsteady.com/index.html?lang=en` | HTTPS 200, `text/html` | Product page, privacy link, and support contact section visible. |
| `https://wowsteady.com/index.html?lang=en#contact` and `https://wowsteady.com/index.html?lang=zh#contact` | Both HTTPS 200, `text/html` | Product-page support anchors recorded in `release-kit.yml`; the English contact section and email were checked in the browser. |

The live site's language switch changed the privacy page between the exact `?lang=zh` and `?lang=en` URLs. Its support email is `postmaster@hndige.com`.

The previously recorded draft and unconfirmed-address wording is no longer present online. The hosted `index.html`, `privacy.html`, `site.js`, and `styles.css` have the same bytes and SHA-256 digests as the local copies. Both language URLs use the same bilingual policy document, with `site.js` selecting the requested language. Hosting provider, request-log retention, email delivery, legal review, and final signed-binary privacy disclosures remain unverified.
