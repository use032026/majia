# Public website and privacy URL check

Checked on 2026-10-12 after the operator provided the policy URLs. No website deployment or store upload was performed in this run.

| URL | Reachability | Browser check |
| --- | --- | --- |
| `https://wowsteady.com/privacy.html?lang=zh` | HTTPS 200, `text/html` | Chinese title, 2026-10-12 effective date, full Chinese policy and support email visible. |
| `https://wowsteady.com/privacy.html?lang=en` | HTTPS 200, `text/html` | English title, 12 October 2026 effective date, full English policy and support email visible. |
| `https://wowsteady.com/index.html?lang=en` | HTTPS 200, `text/html` | Product page, privacy link, and support contact section visible. |
| `https://wowsteady.com/index.html?lang=en#contact` and `https://wowsteady.com/index.html?lang=zh#contact` | Both HTTPS 200, `text/html` | Product-page support anchors recorded in `release-kit.yml`; the English contact section and email were checked in the browser. |

The live site's language switch changed the privacy page between the exact `?lang=zh` and `?lang=en` URLs. Its support email is `postmaster@hndige.com`.

**Content discrepancy:** Both live policy versions still say the production address needs confirmation and describe the page as a draft awaiting publication. The live product page also says the production address is being confirmed. Those statements are inaccurate now that `wowsteady.com` is reachable. The local `website/` files have been corrected, but the correction is not yet reflected online. Hosting provider, request-log retention, email delivery, legal review, and final signed-binary privacy disclosures remain unverified.
