# ReaderEdit

ReaderEdit is an offline-first Flutter workspace for writing, reading, and revising novels in Chinese or English. It has no account system, backend, analytics, advertising, or cloud sync.

## Features

- Create local novels and chapters.
- Import UTF-8 or UTF-16 TXT/Markdown manuscripts through the system file picker.
- Split common Chinese and Markdown chapter headings automatically.
- Read a chapter and switch directly into editing without copying the text elsewhere.
- Run an optional reader-perspective revision pass using Clear, Dragging, and Lost signals.
- Preserve frozen originals, before/after changes, reader notes, and completion checks.
- Store all workspace data locally with atomic snapshots and backup recovery.
- Switch between Simplified Chinese and English, with light and dark appearance support.

## Platform baseline

- Flutter 3.35.7 / Dart 3.9.2
- iOS 15 or newer
- Android 7.0 / API 24 or newer

## Run locally

```bash
flutter pub get
flutter run
```

## Validation

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ipa --release --no-codesign
```

The latest local quality gate passed formatting, analysis, 29 tests, an Android debug build, and an unsigned iOS archive. See [the evidence register](docs/release/EVIDENCE_REGISTER.md) for exact evidence boundaries.

## Release status

The MVP is implemented, but the App Store candidate remains blocked on production identifiers, distribution signing, public privacy/support URLs, current screenshots, App Store Connect metadata, and physical-device validation. No App Store upload or submission has been performed.

- [Product brief](docs/product/PRODUCT_BRIEF.md)
- [Functional review](docs/release/FUNCTIONAL_REVIEW.md)
- [Differentiation report](docs/product/DIFFERENTIATION.md)
- [App Store preflight](docs/release/APP_STORE_PREFLIGHT.md)
