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

No TripCost-specific plugin changes are applied. Navigation, loading failures,
and external-link handling follow the recorded `mini_web` source exactly. When
updating the snapshot, update the pinned commit and `UPSTREAM.json` together
and verify every recorded file against its upstream hash. This application
snapshot does not change either upstream branch.
