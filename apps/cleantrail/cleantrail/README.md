# CleanTrail / 清迹

Offline-first tabular-data quality workbench built with Flutter. It imports CSV, TSV, TXT, or XLSX files through the system picker, confirms the detected format, encoding, or worksheet, detects five common quality problems, lets the user approve or keep every finding, re-inspects after every decision, and exports a CSV plus a compact audit report.

## Product boundary

- No account, backend, analytics, ads, cloud sync, or application-owned network flow.
- The original source file is never overwritten.
- One source snapshot, working copy, and audit trail are stored in the app-private documents directory. An atomic backup supports recovery from an interrupted write.
- Export files are staged in a dedicated temporary directory, offered through the system share sheet, and cleaned after sharing and again on the next launch/export.
- English and Simplified Chinese UI and reports; system light/dark theme.

## Supported input

- CSV, TSV, and TXT with automatic UTF-8/GBK detection and a manual override.
- XLSX workbooks with explicit worksheet selection.
- Source files up to 5 MB.
- Header plus 1–10,000 data rows, 1–100 columns, at most 100,000 cells and 500 detected issues.
- Missing values, normalized duplicate rows, surrounding whitespace, mixed numeric types, and mixed/invalid date formats.

## Run and verify

```sh
flutter pub get
flutter run
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

The built-in sample exercises every rule without needing an external file. Product, evidence, differentiation, functional-review, and App Store preflight documents live under `docs/`.

The checked-in iOS bundle identifier is the placeholder `com.example.cleantrail`. Replace it with the developer-owned identifier and configure distribution signing before treating any archive as an App Store candidate.
