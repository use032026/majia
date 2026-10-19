# Deynu release-kit open items

The user supplied the operator description (independent developer), support contact, privacy effective date (2026-10-19), `com.almanac.lite` package identity, and the published website. HTTPS requests to the following URLs returned HTTP 200:

- Website and support: https://www.almanac1.com/#support
- Chinese privacy policy: https://www.almanac1.com/privacy.html?lang=zh
- English privacy policy: https://www.almanac1.com/privacy.html?lang=en

The following publication checks remain open:

1. Confirm whether the operator's legal name is needed in store and privacy disclosures; "independent developer" is a role description, not a legal name.
2. Complete final legal review and compare the privacy text with the exact signed iOS and Android builds.
3. Check the web host's request logs, cookies, and analytics, and update the website privacy section if the host processes visitor data beyond the local language preference.
4. Publish the updated Deynu website copy and preview images to the existing domain before relying on its public branding. Store runtime screenshots, rendered store graphics, and website previews have now been refreshed locally with Deynu.

The supplied support contact is `CercyServello4757@outlook.com`. The application opens the corresponding published policy in the system browser view, with local data guidance and a retry action if the browser cannot be opened.

The iOS and Android source identifiers now use `com.almanac.lite`; signed archive/AAB identity and store records have not been checked. Other release checks outside this materials pass: compare screenshots and privacy statements with the final signed binaries and SDK inventory; complete store privacy forms, identity and rights review, signed build checks, public URL reachability, and device verification. The current screenshots come from fresh iOS simulator and Android emulator debug builds; their exact capture methods and hashes are recorded in `SOURCE_REGISTER.md` and `capture-provenance.json`.

Apple's App Review Guideline 4.3(b) specifically names fortune-telling apps as a crowded category. Deynu's listing presents its implemented choice, reflection, and folio workflow and avoids prediction claims, but approval remains a review decision.
