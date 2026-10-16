# ReaderEdit open release-material facts

Updated: 2026-10-16, Asia/Shanghai. User confirmation: **全部待定**.

## Material completion blockers

| Fact | Saved manifest value | Consequence |
| --- | --- | --- |
| Responsible legal operator | empty | Policy/operator identity cannot be finalized. |
| Real monitored support email | empty | Both product page and privacy policy lack an actual contact channel. |
| Production domain | empty | Public support/privacy URLs cannot be declared or checked. |
| Privacy effective date | empty | Policy remains a local, non-effective draft. |

The deterministic validator reports **6 errors**: these four manifest fields plus two missing page contacts. They are preserved deliberately. An earlier privacy draft date of 2026-09-30 is not treated as confirmed because the user explicitly left the date undecided. No invented mailbox/domain/date, fake contact link, or validator suppression was used.

Once facts are confirmed, update `release-kit.yml`, replace draft/pending copy and contact areas in both language versions, and review the static policy variants as well. The generator refuses to overwrite non-empty confirmed facts, so first update its audited draft inputs before using it again.

## Separate release readiness items

- App identifiers remain `com.example.readerEdit` (iOS) and `com.example.reader_edit` (Android). Production identities require separate app/release work.
- No `READEREDIT_PRIVACY_URL_*` production value is configured. The actual app shows its unpublished-policy state. After a domain and policy are approved and hosted, the app's JavaScript-disabled WebView can use `privacy-en.html` and `privacy-zh.html`; this run did not configure or test HTTPS integration.
- Confirm intended audience, age rating, launch regions, legal wording, branding/content rights and trademark clearance. Current icon is reused, not newly rights-cleared.
- Review hosting/logging and the exact final SDK inventory, signed release privacy/permission reports, and App Store/Google Play privacy disclosures before submission.
- Real file providers, physical devices, minimum OS support, accessibility and large-text/large-manuscript behavior were not verified in this material-only run. Android tablet captures are not included; phone listing assets are supplied.

## Source UI observations

- The current English library displays **“1 chapters”** for the one-chapter demo. This minor application copy issue is faithfully visible in the real captures. No screenshot retouching or application-code fix was applied.
- A revision queue is scrollable; a partly visible next card at the bottom is an actual app viewport, not a truncated render. The fixed review/export action remains visible.
- Android raw captures contain imperfect OS status text/notification chrome. Prepared sources remove only the system top/bottom strips (crop `0,115,1080,2315` from `1080×2400`); no app control, text, or content was altered. Raw captures and XML remain available for comparison.
