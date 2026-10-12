# Manual visual and website review

Reviewed on 2026-10-12. All source captures came from the current Steady21 app running in the iOS Simulator or Android emulator, using the local demo records described in `CAPTURE_NOTES.md`.

- Viewed both App Store contact sheets and spot checked iPhone and iPad scenes at full resolution. Checked scene order, legibility, safe areas, text contrast, cropping, and that no personal records appear.
- Viewed both Google Play contact sheets and spot checked English and Simplified Chinese phone scenes at full resolution. The phone screenshots show real Android runtime UI; the feature graphics contain only branding and decorative shapes.
- Checked the product and privacy pages in a local browser in English and Simplified Chinese. Both languages render complete page content and link `postmaster@hndige.com` with `mailto:`. The language switch changes the document title, metadata, `<html lang>`, and `?lang=` URL; the selection survives reload. Product-to-policy navigation preserves the language.
- Checked all final image dimensions and modes. App Store: four iPhone images at 1206 × 2622 and three iPad images at 2064 × 2752, all RGB without alpha. Google Play: four phone images per locale at 1080 × 1920 and two feature graphics at 1024 × 500, all RGB without alpha. The Play icon is 512 × 512 RGBA; the App Store icon is 1024 × 1024 RGB.

Public URL reachability and deployed content were checked separately in `PUBLIC_URL_CHECK.md`. The support email and website domain are confirmed; the remaining release checks are listed in `OPEN_ITEMS.md`.
