# PaceJar release-kit open items

## Required identity and contact facts

- Confirm the responsible operator or legal entity.
- Confirm a monitored support email address.
- Confirm the production HTTPS domain and the intended public Support and Privacy Policy URLs.
- Confirm the privacy-policy effective date.

These facts are not present in the target repository. They must not be inferred from a Git username, sibling app, or placeholder domain.

## Production readiness facts outside this material-generation run

- Replace the placeholder bundle identifier `com.example.paceJar` with the final production identifier.
- Complete name, trademark, icon, and domain rights review for the working name “PaceJar”.
- Publish the generated website and verify the public Support and Privacy Policy URLs without authentication.
- Supply the final privacy-policy URL through `PACEJAR_PRIVACY_POLICY_URL` in the release build so the in-app link opens the published policy.
- Review the final signed build's Xcode Privacy Report and complete the matching App Store Connect privacy answers.
- Recheck age rating, category, price, launch regions, mainland China requirements, and all localized metadata in App Store Connect.
- Obtain legal review of the product-specific privacy-policy draft where required.

## Evidence boundaries

- The screenshots in this package use real PaceJar UI rendered by local iPhone and iPad simulators with fictional demo data.
- No physical-device verification, final signed build, upload, App Store Connect processing, TestFlight availability, submission, or App Review result is established by this package.
