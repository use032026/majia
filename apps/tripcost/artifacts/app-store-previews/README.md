# RhinoSmart App Store previews

English App Store screenshot compositions use real iOS Flutter-rendered UI with
fictional deterministic preview data. On 2026-11-03, the RhinoSmart brand label,
production icon, blue background and contact sheets were regenerated. The existing
brand-neutral UI captures in `raw/` were inspected and reused unchanged; no UI was
painted over, no new runtime capture or device verification is claimed.

## Screenshot files

- `final/iphone-6.5/`: four portrait PNGs at 1242 × 2688 pixels.
- `final/iphone-dynamic-island/`: four portrait PNGs at 1206 × 2622 pixels,
  adapted from the 6.5-inch compositions, rather than a separate device capture.
- `final/ipad-13/`: four portrait PNGs at 2064 × 2752 pixels.
- `qa/contact-sheet-*.jpg`: one visual review sheet for each output group.
- `preview-spec.json`: source/output, dimension, copy and branding manifest.

All final PNGs are opaque RGB images with no alpha channel. Original capture
files and existing output paths are preserved.

## Story order

1. Plan every trip with confidence.
2. Scan prices and understand costs.
3. Compare payment methods before paying.
4. See what the trip really cost.

## Regenerate

From the app root, reuse the inspected UI sources and regenerate all compositions:

```sh
python3 tool/generate_app_store_previews.py
python3 tool/generate_dynamic_island_previews.py
```

The specialized compositor preserves the established scene crops and decorative
onboarding illustrations. Its background is drawn reproducibly in code; it does
not rely on the missing historical `backgrounds/` files. Branding comes from
`assets/branding/rhinosmart_app_icon.png`.

To intentionally replace the source captures with current UI before composing:

```sh
flutter test --no-pub test/app_store_preview_capture_test.dart
```

That capture test renders real Flutter widgets with deterministic data. It does
not establish simulator, physical-device or App Store acceptance.
