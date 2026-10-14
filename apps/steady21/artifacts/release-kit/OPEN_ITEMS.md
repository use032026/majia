# Steady21 release material open items

Updated: 2026-10-14. The website was reachable at `https://wowsteady.com` on 2026-10-12; the hosted product and privacy pages matched the local `website/` files. No app or listing was uploaded to either store in that run.

## Public URL follow-up

1. **Review hosting practices:** Confirm the hosting provider's request logs, retention, and any third-party processing, then review the final policy against those facts. The public email's delivery and monitoring have not been tested.

The operator supplied **“独立开发者”** as the formal operator label, **postmaster@hndige.com** as the public support email, **2026-10-12** as the privacy effective date, and the exact English and Chinese policy URLs in `release-kit.yml`. On 2026-10-14, the operator reported successful Apple App ID registration for iOS **`com.steady.lite.app`** and requested that Android remain **`com.steady.lite`**. Whether a personal legal name or other disclosures are required in the chosen storefronts and jurisdictions still needs review.

## Before any store submission

- The iOS source and release configuration now use `com.steady.lite.app`; Android namespace/application ID, launcher class, and repository Android cloud-package registration remain `com.steady.lite`. Confirm the registered Apple Team, signing, provisioning, and App Store Connect record match the iOS ID before a signed release. The dated `IDENTITY_CHECK.md` and `app-facts.json` still describe their 2026-10-12 source snapshot.
- The app still contains the internal Settings copy “Local MVP candidate · not App Review approval.” Remove that wording in a separate app change before release and recapture affected screenshots if the visible UI changes.
- Recheck the final signed binaries, included SDKs and privacy manifests, sharing behavior, privacy disclosure answers, and the in-app hosted policy with its offline summary. The new in-app URL selection and fallback have not been verified on a physical device.
- Confirm the app name, icon, onboarding imagery, and fonts have publication rights and clear any required name checks.
- Review the final website and policy for the selected launch regions and legal requirements. The corrected local text is deployed and matches the hosted pages; legal review is still open.
- The screenshots are from iOS and Android simulators with demo data. No signed distribution build, physical device, App Store Connect or Play Console processing, TestFlight, Play testing, submission, or review has been verified.
