# TripCost App Store previews

English-only App Store screenshot sets generated from real TripCost Flutter
screens with deterministic preview data.

## Upload-ready files

- `final/iphone-6.5/`: four portrait PNGs at 1242 × 2688 pixels.
- `final/iphone-dynamic-island/`: four portrait PNGs at 1206 × 2622 pixels.
- `final/ipad-13/`: four portrait PNGs at 2064 × 2752 pixels.

All final PNGs are opaque RGB images with no alpha channel.

## Story order

1. Plan every trip with confidence.
2. Scan prices and understand costs.
3. Compare payment methods before paying.
4. See what the trip really cost.

## Regenerate

```sh
flutter test --no-pub test/app_store_preview_capture_test.dart
python3 tool/generate_app_store_previews.py
```

The capture test renders the current English TripCost UI at the exact target
physical resolutions. The compositor adds the TripCost brand background and
marketing copy while preserving the real application surface.
