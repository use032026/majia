# Fylto release kit: open items

## User-confirmed facts — 2026-10-21

- Operator: 独立开发者 / Independent developer.
- Support and privacy contact: ashcar1986@icloud.com.
- Privacy policy effective date: 2026-10-21.
- iOS Bundle ID and Android applicationId/namespace: `com.fylto.lite`; Android launcher class is `com.fylto.lite.MainActivity`.
- Production website: https://fylto1.com; support: https://fylto1.com/#support.
- Privacy policy: https://fylto1.com/privacy.html?lang=zh (Chinese), https://fylto1.com/privacy.html?lang=en (English).

These values are saved in `release-kit.yml` and reflected in the current application configuration, website and privacy materials. No personal or company legal name was inferred from the operator description.

## Public policy and support URLs

The user confirmed the production domain and both privacy URLs on 2026-10-21. The homepage and both privacy URLs returned HTTP 200 over HTTPS; their response bodies matched the checked-in website pages at verification time. The application keeps its local privacy note and opens the full online policy in the current app language through a system browser view. Browser-launch failure retains the note and exposes a retry and selectable URL. No selected file or report is passed to the browser. No required identity/contact/domain/effective-date fact remains missing from the manifest; see `QA_REPORT.md` for material validation.

## Further release checks

- Confirm `com.fylto.lite` in the relevant developer accounts and signing configuration, then verify the final signed IPA/AAB identities. Source configuration is not account registration or distribution evidence.
- Fill and verify the confirmed support/privacy URLs in the store consoles when preparing a submission; this source change does not update either console.
- Reconcile privacy statements with the final signed packages, plugin privacy manifests, Xcode Privacy Report, App Store App Privacy answers, Google Play Data safety form, file-provider temporary copies and backup behavior.
- Final signing, physical-device behavior, accessibility, minimum-version coverage and store submission remain separate release checks.

## Existing image provenance

The Fylto website/store images were captured before the package-identity update, from the earlier `com.example.filerecheck` simulator/emulator builds. Their displayed branding is already Fylto and the photographed scenes are unchanged by this configuration/contact update. The original build identity and validation scope remain in `CAPTURE_NOTES.md`; these images do not prove the new package's runtime or signed identity. `name-audit.json` retains OCR and SHA-256 records for all 44 image files.
