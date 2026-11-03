# STMini online Web for TripCost

This is a source snapshot of the `mini_web` branch of
https://github.com/fsst-ios/stmini_flutter at
`78b5a71561babfdf070488a08941eb94d2072e40`.
`UPSTREAM.json` records the original files and their SHA-256 hashes.
The app resolves this package through a repository-relative path, so local and
cloud builds use the same sources without a sibling checkout or private Git SSH
credentials.

The package supports iOS and Android online pages through `initialize`,
`openWeb`, `closeWeb`, lifecycle events, and the host bridge. It contains no Mini
ZIP installer, offline runtime, package resources, or `openMini` API.

The downstream patch adds native loading-failure feedback, an in-page Retry
button, and a navigation-bar Reload button on both platforms. Retry loads the
failed document in the existing page, preserving its URL query. Cancellation and
subresource failures do not become whole-page errors. Network authorization is
still controlled by the operating system; after granting access, the user can
retry without leaving the page. No startup request or network probe is added.
Explicit top-level `mailto:` link taps continue to open the system mail app;
iframe and script navigation do not receive that permission.

Changes from the recorded snapshot are limited to the two native presentation
files:

- `ios/Classes/Web/OnlineWebViewController.swift`
- `android/src/main/kotlin/com/fsst/stmini_flutter/web/OnlineWebActivity.kt`

When updating the snapshot, compare against `UPSTREAM.json` and retain or replace
the retry patch with an equivalent upstream implementation. Shared Web changes
submitted upstream must follow that repository's `main`-first synchronization
contract. This application snapshot does not change either upstream branch.
