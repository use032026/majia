# PaceJar release-kit open items

Google Play listing copy, the existing app icon at Play size, bilingual Android
phone screenshots, and bilingual feature graphics have been generated and checked.
The remaining blockers below are facts or external release steps, not missing artwork.

## Required identity and contact facts

- Confirm the responsible operator or legal entity.
- Confirm a monitored support email address.
- Confirm the production HTTPS domain and the intended public Support and Privacy Policy URLs.
- Confirm the privacy-policy effective date.

These facts are not present in the target repository. They must not be inferred from a Git username, sibling app, or placeholder domain.

## Production readiness facts outside this material-generation run

- Replace the placeholder bundle identifier `com.example.paceJar` with the final production identifier.
- Replace the placeholder Android package `com.example.pace_jar` with the final production application ID.
- Complete name, trademark, icon, and domain rights review for the working name “PaceJar”.
- Publish the generated website and verify the public Support and Privacy Policy URLs without authentication.
- Supply the final privacy-policy URL through `PACEJAR_PRIVACY_POLICY_URL` in the release build so the in-app link opens the published policy.
- Review the final signed build's Xcode Privacy Report and complete the matching App Store Connect privacy answers.
- Review the final Android App Bundle, complete the matching Google Play Data safety answers, and confirm target audience, content rating, category, tags, pricing, countries, and account/contact details in Play Console.
- Recheck age rating, category, price, launch regions, mainland China requirements, and all localized metadata in App Store Connect.
- Obtain legal review of the product-specific privacy-policy draft where required.

## Evidence boundaries

- The screenshots in this package use real PaceJar UI rendered by local iPhone and iPad simulators with fictional demo data.
- The Google Play screenshots use real PaceJar UI rendered by a local Pixel 7 Android emulator with fictional English and Chinese demo data; iOS screenshots were not reused for Play.
- The Google Play feature graphics are brand artwork only and contain no device frame, app UI, store badge, ranking, price, or call to action.
- No physical-device verification, final signed build, IPA/AAB upload, App Store Connect or Play Console processing, TestFlight or Play testing availability, submission, or store review result is established by this package.
