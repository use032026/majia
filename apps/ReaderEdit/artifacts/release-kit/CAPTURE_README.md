# Real runtime capture provenance

Date: 2026-10-16 (Asia/Shanghai). App version: 1.0.0 (1). Real app rendering; no functional UI was generated or painted.

| Platform | Runtime | Dedicated capture target | Raw size | Local binary |
| --- | --- | --- | --- | --- |
| iPhone | iPhone 17 Pro / iOS 26.5 Simulator | ReaderEdit ReleaseKit iPhone, `AE695757-20C3-4D14-B14C-57456D5F7B8D` | 1206×2622 | `build/ios/iphonesimulator/Runner.app` |
| iPad | iPad Pro 13-inch (M5) / iOS 26.5 Simulator | ReaderEdit ReleaseKit iPad, `E5161756-C751-463F-8BB6-80871BD124AC` | 2064×2752 | same simulator app |
| Android phone | Pixel 7 / Android 15 (API 35) emulator | `Pixel_7_API_35`, `emulator-5554` | 1080×2400 | `build/app/outputs/flutter-apk/app-debug.apk` |

The existing local debug binaries were reused. No build was started in this run, and no signed distribution artifact was generated. Installed binary/source/capture fingerprints are recorded in `capture-manifest.json`. Source audit and observed UI support current material claims; this is not a reproducible signed-release build attestation.

## Demo content and scene route

`make_demo.py` writes `demo-en.json` and `demo-zh.json`. They contain an original fictional manuscript based on the app's own built-in Fog Station sample, an example reader note and a manually revised paragraph. These are synthetic demonstration records, not a user's personal draft, actual reader feedback, AI results or metrics. They use the app's schema-v2 local snapshot format. `seed_demo.py` loads them only for capture workspaces; the running app displays and navigates its normal production UI code.

Four phone scenes per language:

1. Library: one local novel, one chapter and one revision session.
2. Read: open the novel → first chapter. The Edit control belongs to the real app; the screenshot does not claim that edit/save was exercised this run.
3. Queue: back to home → existing session, with Clear/Dragging/Lost manually supplied in the demo.
4. Compare: Review & export → View every change, showing one original/revised pair.

Two iPad scenes per language: library and revision queue. Use Settings to switch the actual app language. Simulator preference caches can retain the old language after seeding a second fixture; verify the visible UI and switch it through Settings before capturing.

The iOS raw images were captured with `xcrun simctl io <device> screenshot`. Status time is a normal simulator override of 9:41. Android raw screenshots and corresponding accessibility XML were captured using the Android SDK (`adb exec-out screencap -p` and UIAutomator); `capture_android.py` navigates only controls present in the current UI hierarchy.

`generate_package.py` prepares Android crops excluding only system status/navigation strips, preserving all app pixels. The specification renderer scales full app captures without stretching. Feature graphics are decorative brand fields with text only and contain no simulated app UI, device, store badge or icon.

## Rebuild material artwork

From repository root, after reviewing draft inputs and the missing facts:

```sh
python3 apps/ReaderEdit/artifacts/release-kit/generate_package.py
python3 .codex/skills/app-store-release-kit/scripts/render_previews.py --spec apps/ReaderEdit/artifacts/app-store-previews/preview-spec.json
python3 .codex/skills/app-store-release-kit/scripts/render_previews.py --spec apps/ReaderEdit/artifacts/google-play-listing/preview-spec.json
python3 .codex/skills/app-store-release-kit/scripts/validate_release_kit.py apps/ReaderEdit --report apps/ReaderEdit/artifacts/release-kit/QA_REPORT.md
```

Do not seed a personal device or unrelated workspace. No real file-provider interaction, live production URL, device testing, store upload or review status is implied by these captures.
