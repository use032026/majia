# Refqo

An offline household refill planner for iOS and Android. English brand name; English and Simplified Chinese UI. No accounts, ads, analytics or application backend.

Refqo pools one exact supply SKU across several appliances. A 30/60/90-day plan counts scheduled replacements, subtracts shared stock once and produces a net purchase quantity. Receive spares, record replacements, undo the latest stock transaction, and export/restore your library.

## Run

Local validated tools: Flutter 3.35.7 / Dart 3.9.2; Xcode 26.5. iOS deployment target 15.0. Android minimum API24, compile/target API36. `pubspec.lock` fixes dependencies. The installed Flutter cache and source have version inconsistencies; do not infer a newer SDK from its installation path.

```sh
flutter pub get
flutter run
flutter test
flutter analyze
```

Device workflow and screenshots:

```sh
REFQO_DEVICE=qa flutter drive --driver=test_driver/app.dart --target=integration_test/app_test.dart -d DEVICE_ID
```

The runtime test **erases only this app's QA library** on its selected device and writes representative test data. Use a disposable simulator/emulator installation, not your real library. Screenshots appear in `docs/release/evidence/runtime/qa/`. Normal app builds contain no sample library.

## Behavior and boundaries

- Exact part codes are separate supplies; names never imply compatibility. Fit confirmation and intervals come from the user/manufacturer, not the app.
- Forecast includes the horizon end date. Overdue plans count one immediate replacement, then resume cadence from today; historical missed cycles are not purchased retroactively.
- Stored JSON is validated, size/count bounded, atomically committed and previous-save recoverable. Corrupt loads lock ordinary changes and offer explicit recovery.
- Backups are readable JSON. File providers, system backups and explicit sharing destinations may use cloud storage. Android cloud backup is disabled; platform migration behavior is outside app control.
- Transactions protect linked records from destructive edits. Undo runs latest-first. A future archive flow would make retiring old records easier without removing their history.
- Locale and appearance follow the system until an explicit override. Onboarding can be skipped, persists and is replayable.
- No background notifications, safety/lifespan recommendations, automatic fit database or online purchases.

## Delivery status

See [functional review](docs/release/FUNCTIONAL_REVIEW.md), [UI acceptance](docs/release/UI_ACCEPTANCE.md), [differentiation](docs/product/DIFFERENTIATION.md) and [store preflight](docs/release/APP_STORE_PREFLIGHT.md). Local code/tests are distinct from distribution readiness. `com.example.refqo` is a local identifier; production signing, real developer/support/privacy information and store-name verification are not configured. No upload or submission was performed.

Original icon source: `assets/brand/refqo.svg`, reproducible with `tools/generate_brand.py` (Pillow). Native launch has no copy, ads, fake progress or artificial delay. All third-party Flutter/package licenses remain under their upstream terms; no competitor assets were used.
