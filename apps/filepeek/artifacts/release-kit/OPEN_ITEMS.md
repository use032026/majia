# Fylto release kit: open items

The named app is `apps/filepeek`; its displayed product name is Fylto. The user confirmed on 2026-10-13 that the following publication facts are **not yet determined**. They remain empty in `release-kit.yml` and intentionally cause six QA errors:

1. Legal operator name.
2. Real support email, to appear on the product and privacy pages.
3. Production HTTPS domain and public page URLs.
4. Privacy policy effective date.

The website and privacy policy are review drafts with visible pre-publication notices. Do not host or submit them as final policy or support pages until those facts are confirmed, the copy is reviewed, and the release-kit validator is rerun.

## Further release checks

- `com.example.filerecheck` is a development Bundle ID and Android application ID. Confirm the owned production identities before store submission.
- Reconcile privacy statements with the final signed iOS and Android packages, plugin privacy manifests, Xcode Privacy Report, App Store App Privacy answers, Google Play Data safety form, system file-provider temporary copies, and backup behavior.
- Confirm final store name and legal rights in target regions, public URL reachability, and complete platform listing fields in the store consoles.
- Final signed IPA/AAB, physical-device behavior, accessibility, and minimum-version coverage are outside this material-generation run.

## Material refresh — 2026-10-21

All current website product screenshots, App Store and Google Play source/final screenshots, feature graphics, contact sheets and the CSV editor QA images have been refreshed for Fylto. The English full description, Apple keywords and Google Play short description were also updated. App facts and deterministic QA were regenerated.

`CAPTURE_NOTES.md` records current build/device provenance, debugger-loaded repository sample states, counts, dimensions and validation limits. `name-audit.json` records OCR and hashes for 44 images with no recognized old branding. These current screenshots do not rely on the earlier FileRecheck captures.

The six remaining QA errors all concern the previously unconfirmed publication facts above; image/metadata checks passed. This material refresh does not resolve production identities, signing, public contacts/URLs, legal review, physical-device proof or store submission.
