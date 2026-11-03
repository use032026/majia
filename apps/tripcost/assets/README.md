# RhinoSmart artwork

The supplied `branding/rhinosmart_app_icon.png` is the original 2048 × 2048
RhinoSmart artwork. Regenerate iOS/Android icons, website/Play icons, and startup
marks with `python3 tool/generate_branding_assets.py` (requires Pillow).

The following assets do not change the startup state or routing logic:

- `branding/launch_mark.png`: Flutter startup mark.
- `onboarding/scan_price.png`: scan-prices onboarding illustration.
- `onboarding/compare_payments.png`: payment-comparison illustration.
- `onboarding/track_budget.png`: trip-budget illustration.

The native iOS launch mark is stored separately as light/dark 1x, 2x, and 3x
files under `ios/Runner/Assets.xcassets/LaunchImage.imageset`. Keep its visible
size at 96 points so the native screen and Flutter first frame remain aligned.
Both light and dark startup marks use the same supplied square artwork.
