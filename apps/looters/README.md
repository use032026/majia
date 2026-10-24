# PaceJar · 节奏罐

PaceJar is an offline-first Flutter savings planner for one focus goal. It records manual saved, withdrawn, and skipped events; compares planned and actual pace; offers transparent recovery choices; and preserves an append-only plan timeline. It does not use accounts, connect to banks, move money, or provide financial advice.

## Local development

The project is pinned to Flutter 3.35.7 through FVM.

The iOS deployment target is 15.0 or later. `ITSAppUsesNonExemptEncryption` is set to the boolean `NO` value in the Runner plist.

```sh
fvm flutter pub get
fvm flutter test
fvm flutter analyze
fvm flutter run
```

## Current status

- Product differentiation: passed (`4.0 / 5`).
- Functional review: passed with no open P0/P1.
- Automated checks: formatting, analysis, 29 tests, Android debug build, and iOS unsigned archive passed.
- App Store preflight: blocked by production identity, public privacy/support URLs, distribution signing, trademark/name clearance, and external App Store Connect work.
- Upload: not performed.

See [the product brief](docs/product/PRODUCT_BRIEF.md), [functional review](docs/release/FUNCTIONAL_REVIEW.md), [App Store preflight](docs/release/APP_STORE_PREFLIGHT.md), and [evidence register](docs/release/EVIDENCE_REGISTER.md).

## Online privacy policy

The iOS privacy-policy button uses the existing HTTPS URL supplied through `PACEJAR_PRIVACY_POLICY_URL`, including the selected language. If no valid URL is supplied, the existing unavailable-link message is shown. Other platforms keep the existing in-app browser route.

On an explicit tap, the app requests the actual policy through an ephemeral `URLSession` and displays that response in its own nonpersistent `WKWebView`. First-network authorization is handled by iOS when required by the device and its current permission state. Loading failures offer retry, copy address, and close; failure to present the native page uses the existing Flutter failure message. No startup request or unrelated probe is added.
