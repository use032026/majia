# FileRecheck release kit: open items

The named app is `apps/filepeek`; its displayed product name is FileRecheck. The user confirmed on 2026-10-13 that the following publication facts are **not yet determined**. They remain empty in `release-kit.yml` and intentionally cause six QA errors:

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

## Screenshot provenance

`artifacts/app-store-previews/source/` contains real FileRecheck runtime captures from iPhone 17 Pro / iOS 26.5 and iPad Pro 13-inch (M5) / iOS 26.5 simulators. `artifacts/google-play-listing/source/` contains real FileRecheck runtime captures from a Pixel 7 API 35 Android emulator in English and Simplified Chinese. All file content shown is from `docs/release/review_samples/`, specifically `check.json`, `compare.json`, and `check.csv`. The final images are derived from these captures with factual text overlays. They are simulator evidence, not physical-device or signed-release evidence.
