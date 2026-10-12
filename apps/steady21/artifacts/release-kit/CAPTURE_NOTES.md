# Store screenshot provenance

Captured on 2026-10-12 from the current Steady21 Flutter source at `0df2f21`, using unsigned debug builds solely for local material generation.

| Source directory | Runtime | Device | Source size | Scenes |
| --- | --- | --- | --- | --- |
| `artifacts/app-store-previews/source/` | iOS 18.3 Simulator | iPhone 16 Pro | 1206 × 2622 | Onboarding, Today, Journey, Settings |
| `artifacts/app-store-previews/source/` | iOS 18.3 Simulator | iPad Pro 13-inch (M4) | 2064 × 2752 | Today, Journey, milestone review |
| `artifacts/google-play-listing/source/` | Android API 35 emulator | Pixel 7, viewport set to 1080 × 1920 | 1080 × 1920 | Onboarding, Today, Journey, Settings in English and Simplified Chinese |

The app rendered every source capture. The reproducible local demo data is saved in `seed-store-demo.json`, `seed-store-demo-zh.json`, and `seed-store-onboarding-zh.json`; it was adapted from `docs/release/evidence/runtime/seed-ipad.json`, shifted to end on 2026-10-12, and shortened for readable store examples. It contains no user records. The iOS captures came from `xcrun simctl io ... screenshot`; the Android captures came from `adb exec-out screencap -p`. The renderer composites each unaltered app capture with text and a decorative background, then exports RGB files. The Google Play feature graphics contain no UI capture or device mockup.

The source captures are simulator/emulator evidence. They are not physical-device proof, signed-release screenshots, store acceptance, or a privacy audit of final binaries.

After these captures, the source bundle/application ID was changed to `com.steady.lite` on both platforms. This configuration change did not alter the captured UI. The captures were not remade or represented as signed-release output.

The in-app privacy view was later pointed at the verified public policy URLs. None of these Store screenshots displays that view, so the screenshot scenes were not recaptured for this change.
