# Steady21 release material open items

Updated: 2026-10-12. The website is reachable at `https://wowsteady.com`; the hosted product and privacy pages match the local `website/` files. No app or listing was uploaded to either store in this run.

## Public URL follow-up

1. **Review hosting practices:** Confirm the hosting provider's request logs, retention, and any third-party processing, then review the final policy against those facts. The public email's delivery and monitoring have not been tested.

The operator supplied **“独立开发者”** as the formal operator label, **postmaster@hndige.com** as the public support email, **com.steady.lite** as the common iOS/Android app ID, **2026-10-12** as the privacy effective date, and the exact English and Chinese policy URLs in `release-kit.yml`. These facts are recorded verbatim. Whether a personal legal name or other disclosures are required in the chosen storefronts and jurisdictions still needs review.

## Before any store submission

- The iOS bundle ID, Android namespace/application ID, Android launcher class, and repository Android cloud-package registration now use `com.steady.lite`. Register/verify this ID in the developer accounts and align signing, provisioning, and store records before a signed release.
- The app still contains the internal Settings copy “Local MVP candidate · not App Review approval.” Remove that wording in a separate app change before release and recapture affected screenshots if the visible UI changes.
- Recheck the final signed binaries, included SDKs and privacy manifests, sharing behavior, privacy disclosure answers, and the in-app hosted policy with its offline summary. The new in-app URL selection and fallback have not been verified on a physical device.
- Confirm the app name, icon, onboarding imagery, and fonts have publication rights and clear any required name checks.
- Review the final website and policy for the selected launch regions and legal requirements. The corrected local text is deployed and matches the hosted pages; legal review is still open.
- The screenshots are from iOS and Android simulators with demo data. No signed distribution build, physical device, App Store Connect or Play Console processing, TestFlight, Play testing, submission, or review has been verified.
