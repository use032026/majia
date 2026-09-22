# Steady21 / 微成

Steady21 is an offline-first, bilingual Flutter app for running a focused behavior experiment. Twenty-one days is treated as a starting and reflection milestone—not a guarantee that a habit has formed.

## Core loop

- Define one cue, a standard action, and a smaller minimum action.
- Record a standard completion, minimum completion, or pause each day.
- Turn interruptions into explicit obstacle and recovery observations.
- Review decisions at 7, 14, and 21 practice days.
- Keep a local, readable experiment report and archived history.

The app has no account system, backend, analytics, advertising, or in-app purchase. Records are stored as JSON in the application sandbox.

## Development

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

The reviewed local toolchain used Flutter 3.35.7, Dart 3.9.2, and Xcode 26.5.

## Current evidence

- Functional review: passed with no open P0/P1/P2.
- Automated tests: 24 passed.
- Android Debug APK and unsigned iOS Release Archive: built successfully.
- iOS simulator inspection: iPhone and iPad, Simplified Chinese/English, light/dark appearance, larger text, and a 31-day stress report.

See [`docs/release/FUNCTIONAL_REVIEW.md`](docs/release/FUNCTIONAL_REVIEW.md) and [`docs/release/EVIDENCE_REGISTER.md`](docs/release/EVIDENCE_REGISTER.md).

## Release status

The Flutter MVP is complete within its reviewed scope, but the App Store preflight is **blocked**. The repository still uses a placeholder Bundle ID and default Flutter branding; it has no distribution signature, public privacy/support URLs, final store screenshots, or App Store Connect metadata. Nothing has been uploaded or submitted.

See [`docs/release/APP_STORE_PREFLIGHT.md`](docs/release/APP_STORE_PREFLIGHT.md) and [`docs/release/GAP_BACKLOG.md`](docs/release/GAP_BACKLOG.md).
