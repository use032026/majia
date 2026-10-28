# Open items — ASTFX release materials

Updated: 2026-10-28 (Asia/Shanghai). The user supplied the published website URLs; this configuration task does not deploy the website or upload to either store.

## Confirmed configuration

- **Operator:** 独立开发者 (Independent developer).
- **Support and privacy contact:** evwascr0317@icloud.com.
- **Privacy effective date:** 2026-10-28.
- **iOS bundle identifier and Android application ID:** com.astfx.lite. Native source configuration and release metadata are aligned; no store registration, signing or new binary is verified by this change.

The user supplied these values on 2026-10-28, superseding the previous pending record. They are saved in release-kit.yml and facts-confirmation.json and reflected in the bilingual website and policy.

## Confirmed production URLs

- **Website:** https://astfx1.com
- **Chinese privacy policy:** https://astfx1.com/privacy.html?lang=zh
- **English privacy policy:** https://astfx1.com/privacy.html?lang=en
- **App default:** https://astfx1.com/privacy.html; the current app language selects `lang=zh` or `lang=en`. `PRIVACY_POLICY_URL` remains an optional build/run override.
- All three public URLs returned HTTP 200, and the two privacy URLs displayed the matching language, contact and effective date in a desktop browser on 2026-10-28.
- The live policy still contains the old statement that its domain awaits confirmation. The local bilingual policy source has been corrected; republishing that website source is outside this configuration task.

## Before actual release, outside this generation request

- Confirm hosting provider and hosting-log practices, child audience and age rating; legal review and store ownership/signing checks remain outside this configuration update.
- Current raw UI captures use iOS 26.2 simulators and an Android 15/API 35 emulator. No physical-device validation is claimed.
- Imported UI is the app’s own six-row quality_sample.csv. Export screens accurately show unresolved issues and draft status; they do not claim the sample is fully repaired or that an external destination saved a file.
- This task did not deploy or republish the website, change App Store Connect/Play Console, create a distribution-signed build, upload IPA/AAB, or submit testing/review. Public URL checks do not prove native WebView/device behavior.
- The 2026-10-27 ZIP, asset inventory and browser screenshots remain historical evidence. They were not regenerated for the 2026-10-28 configuration update and may show the previous contact/date; use the current website source and release-kit.yml for the updated facts.
