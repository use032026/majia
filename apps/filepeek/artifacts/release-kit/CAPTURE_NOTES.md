# Capture notes — FileRecheck

- Source code checkout: `451cbf42eff9bcb09c231843266dd68e4f7859ff` at capture time; the working tree gained only this target app's release-kit outputs during the run.
- iOS source: iPhone 17 Pro simulator, iOS 26.5, 1206 × 2622; iPad Pro 13-inch (M5) simulator, iOS 26.5, 2064 × 2752. Captured with `simctl io screenshot` from the installed `com.example.filerecheck` simulator app. The app's current flow uses the in-app system file picker and has no incoming share extension.
- Android source: Pixel 7 API 35 emulator at 1080 × 1920 display override. Captured from installed `com.example.filerecheck` with Android screencap after using the in-app file picker. English and Chinese UI states were captured separately.
- Review sample files: `docs/release/review_samples/check.json`, `compare.json`, and `check.csv`. No personal files were selected for final artwork.
- Image treatment: each source is converted to RGB and placed without changing functional UI; the renderer adds factual headlines and a decorative background. Google Play feature graphics contain no UI image or device frame.
- Visual review: contact sheets and full-resolution examples inspected for scene order, cropping, safe areas, text legibility, and sample-data exposure. Current iPad UI leaves substantial empty space around a centered work area; the capture reflects the implemented layout.
