# RhinoSmart website

Static, dependency-free website for RhinoSmart.

## Files

- `index.html`: bilingual product website
- `privacy.html`: bilingual privacy policy
- `styles.css`: responsive layout and print styles
- `site.js`: language preference and mobile navigation
- `assets/`: web-sized copies of existing RhinoSmart brand artwork

## Local preview

Serve this directory with any static HTTP server, then open `index.html`. Opening
the files directly also works, but an HTTP preview more closely matches hosting.

## Before production publishing

1. Confirm that `djl13333995679@163.com` is the public privacy/support address.
2. Verify that any App Store download link points to the existing live listing.
3. Name the production hosting provider in the website-data section of
   `privacy.html` if it keeps access logs.
4. Recheck the policy whenever app permissions, SDKs, sync fields, providers, or
   data deletion behavior change.
5. Have the final policy reviewed for the countries and regions where the app is
   distributed; this repository draft is product-specific compliance content,
   not legal advice.
