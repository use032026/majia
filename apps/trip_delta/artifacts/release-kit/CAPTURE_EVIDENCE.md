# Runtime capture and artwork evidence

Captured on 2026-10-14 (Asia/Shanghai) from Trip Delta simulator/debug builds. After the iOS bundle ID changed, the iOS app was rebuilt, and the built `Runner.app/Info.plist` resolved `CFBundleIdentifier` to `com.tripdelta.lite`. That build was installed and launched on both iOS simulators before the App Store screenshots were recaptured. The new iOS demo state is `capture-demo-ios-en.json`; the Android captures use `capture-demo-en.json` and `capture-demo-zh.json`. All trip names, expenses, amounts, and reflections are fictional examples; no user's real trip records were used.

- **App Store sources:** iPhone 17 Pro simulator, iOS 26.5, 1206 × 2622; iPad Pro 13-inch (M5) simulator, iPadOS 26.5, 2064 × 2752. All seven sources in `../app-store-previews/source/` were freshly captured from `com.tripdelta.lite` with `simctl io screenshot`; none of the earlier PNG files was used as a renderer input. The four iPhone scenes show home, active-trip detail, a scrolled category comparison, and completed-trip review. Three iPad scenes show home, active-trip detail, and category comparison. All seven source SHA-256 values differ from the earlier captures.
- **Google Play sources:** Pixel 7 API 35 Android emulator, 1080 × 1920 display override, captured separately with English and Chinese demo records. Sources are in `../google-play-listing/source/`. Each locale has home, active-trip detail, category comparison, and completed-trip review.
- **Final store images:** `preview-spec.json` in each store folder records the real source file, output path, overlay text, and size. The renderer placed the real UI over a decorative brand gradient. Google Play feature graphics contain no UI capture or device frame.
- **Website images:** The app icon comes from `assets/brand/app_icon.png`; the English product image was refreshed from the new iPhone home capture, while the Chinese product image remains a real Android emulator capture. The 512 × 512 Play icon is resized from the same app asset.

The captures establish simulator/emulator appearance only. They do not prove a signed release build, physical-device behavior, store acceptance, or public distribution.

## Visual review

The newly rendered App Store contact sheets, selected full-resolution finals, and live iOS simulator states were opened after recapture. Scene order, brand colors, image cropping, and the absence of real user data were checked. The final images are RGB and contain no alpha. The in-app iPhone card truncation is recorded in `OPEN_ITEMS.md`; this is the remaining visual concern before treating the iPhone set as final submission art. The Android contact sheets, localized Play text, and feature graphic were reviewed during the earlier material pass.

The local English and Chinese product and privacy pages were opened in a browser. Language switching changed visible content, page title, description metadata, and `<html lang>`, and the product-to-privacy link retained the selected language. All local page and image requests succeeded. Public hosting was not tested.
