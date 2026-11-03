# RhinoSmart Google Play listing assets

## Listing files

- `app-icon-512.png`: 512 × 512 production icon.
- `final/en-US/phone/`: five English-overlay phone screenshots at 1080 × 1920.
- `final/zh-CN/phone/`: five Simplified Chinese-overlay phone screenshots at 1080 × 1920.
- `final/feature-graphic-en.png`: 1024 × 500 RGB English feature graphic.
- `final/feature-graphic-zh.png`: 1024 × 500 RGB Simplified Chinese feature graphic.
- `qa/contact-sheet-*.jpg`: visual review sheets for phone and feature artwork.
- `short-description-en.txt`: English short description for the main store listing.
- `../app-store-listing/description-en.txt`: shared English full description for both stores.

On 2026-11-03 all ten screenshot compositions, both brand-led feature graphics and
both contact sheets were regenerated for RhinoSmart. The existing sources in
`source/` are real target-app UI captured from a Pixel 7 API 35 Android emulator
at 1080 × 1920, using fictional deterministic preview data. They were inspected
for obsolete public names/icons and reused unchanged. The source UI is English
under both localized overlay sets. No UI was repainted; no new Android capture or
physical-device verification is claimed.

## Regenerate

From the app root, reuse the inspected Android captures:

```sh
python3 ../../.codex/skills/app-store-release-kit/scripts/render_previews.py \
  --spec artifacts/google-play-listing/preview-spec.json
```

To intentionally replace the source captures first, start an Android emulator,
run `flutter run -d <android-device> -t tool/google_play_preview.dart`, and capture
the five corresponding scenes into `source/` before running the compositor.

The final images are opaque RGB files. Overlay copy occupies the top safe area
and is localized independently from the English demo UI. Feature graphics use
the exact RhinoSmart name and contain no device frame or UI screenshot.
