# EchoPage / 回声页

An offline bilingual Flutter diary built around reflection threads rather than isolated pages:

`Page → Future Question → Scheduled Revisit → Echo → Close or Continue`

## Current scope

- Chinese and English; system/light/dark appearance.
- No account, developer backend, ads, analytics, tracking, IAP or runtime permissions.
- Local JSON storage with pending writes, a readable in-app backup, explicit recovery, Recently Deleted and backup sanitization on permanent deletion.
- iPhone/iPad responsive UI and Android project support.

The app does not send diary content to a developer service. Operating-system backup, migration and restore may include app sandbox data according to platform and user settings.

## Run and verify

```bash
flutter pub get
flutter run
flutter analyze --no-pub
flutter test --no-pub
```

The full local gate and its limitations are recorded in `docs/release/evidence/automation/20260930T105552+0800/QUALITY_GATE.md`. The App Store preflight is intentionally blocked until production identity, signing, public URLs, metadata and compliant screenshots exist. No store upload was performed.

## Documents

- Product thesis and acceptance: `docs/product/PRODUCT_BRIEF.md`
- Market evidence: `docs/product/MARKET_EVIDENCE.md`
- Differentiation: `docs/product/DIFFERENTIATION.md`
- Functional review: `docs/release/FUNCTIONAL_REVIEW.md`
- App Store preflight: `docs/release/APP_STORE_PREFLIGHT.md`
- Release gaps: `docs/release/GAP_BACKLOG.md`
