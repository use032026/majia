# RoamSum Google Play listing assets

## Upload-ready files

- `app-icon-512.png`: 512 × 512 RGBA production icon, 253,813 bytes.
- `final/en-US/phone/`: five English-overlay phone screenshots at 1080 × 1920.
- `final/zh-CN/phone/`: five Simplified Chinese-overlay phone screenshots at 1080 × 1920.
- `final/feature-graphic-en.png`: 1024 × 500 RGB English feature graphic.
- `final/feature-graphic-zh.png`: 1024 × 500 RGB Simplified Chinese feature graphic.
- `short-description-en.txt`: English short description for the main store listing.
- `../app-store-listing/description-en.txt`: shared English full description for both stores.

All screenshot sources in `source/` are real RoamSum UI captured from a Pixel 7 API 35 Android emulator at 1080 × 1920. The capture build uses fictional, deterministic preview data and the shipping Flutter UI. It does not contain personal user data.

## Regenerate

1. Start an Android emulator.
2. Run `flutter run -d <android-device> -t tool/google_play_preview.dart`.
3. Capture the five documented scenes into `source/`.
4. Run:

   ```sh
   python3 ../../.codex/skills/app-store-release-kit/scripts/render_previews.py \
     --spec artifacts/google-play-listing/preview-spec.json
   ```

The final images are opaque RGB files. The overlay copy occupies the top safe area and is localized independently from the English demo UI.
