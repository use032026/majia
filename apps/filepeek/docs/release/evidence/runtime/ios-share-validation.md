# iOS share import simulator validation — 2026-10-12

Device: iPhone 16 Pro simulator, iOS 18.3 (`61B7E0B8-9ECD-42A6-A161-3A9B1DDE9256`). The app and share extension were built with `xcodebuild` for the generic iOS Simulator destination and local ad-hoc signing (`CODE_SIGN_IDENTITY=-`, empty `DEVELOPMENT_TEAM`). The build ended with `BUILD SUCCEEDED`.

Both simulated entitlement files include `com.apple.security.application-groups = [group.com.example.filepeek]`, and `simctl get_app_container ... group.com.example.filepeek` returned the same App Group container for this installation. The group ID and app ID are development placeholders; distribution signing and the final App Group registration remain release blockers.

An earlier plugin-only probe built but did not deliver a Files attachment to the main app; the app remained on the baseline file, and an inspection found an empty `ShareKey`. That probe's full log was not retained, so the exact contribution of the plugin setup versus missing App Group entitlements in an unsigned simulator build is unresolved. The final signed-simulator flows below are the affirmative runtime evidence.

## Actual Files share flows

1. **Background return, distinct file with a space in its name.** FilePeek displayed `baseline_old.json` (36 B, `source=baseline-old`). In Files, the exported `share check_checked.json` (43 B, `source=space-name-probe`) was shared to FilePeek. The extension showed “Saved — Open FilePeek to view the shared file.” Returning manually to FilePeek displayed `share check_checked.json` and `source=space-name-probe`. See [before](ios-share-before-baseline.png), [extension prompt](ios-share-saved-open-app.png), and [after](ios-share-resume-import-space-name.png).
2. **Cold start.** `simctl terminate` stopped FilePeek. A different 48 B JSON file was shared from Files; the extension showed the saved prompt. Manually launching FilePeek loaded that file and displayed `source=share-extension-probe`. See [cold start result](ios-share-cold-start-import.png).
3. **Cleanup and latest share.** After each successful import, App Group `ShareKey` was absent and the imported file plus empty UUID subdirectory were gone. A final signed-build run shared `baseline_old.json` while an obsolete file from an earlier failed experimental build existed. The extension retained only the new pending file; after opening FilePeek, `find` showed the inbox directory empty. The final extension log contained `[FilePeekShare] saved file to App Group inbox` at 18:41:27.

The share extension uses only the App Group handoff and an explicit manual-open prompt. It does not call `UIApplication.open`, `openURL:`, or a responder-chain workaround. These observations are simulator evidence; physical-device validation is still open.
