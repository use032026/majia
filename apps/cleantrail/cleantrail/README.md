# CleanTrail / 清迹

Offline-first tabular-data quality workbench built with Flutter. It imports CSV, TSV, TXT, or XLSX files through the system picker, confirms the detected format, encoding, or worksheet, detects five common quality problems, lets the user approve or keep every finding, re-inspects after every decision, and exports a CSV plus a compact audit report.

## Product boundary

- No account, backend, analytics, ads, or cloud sync. Table processing stays on-device; the optional online privacy page loads only after the user opens it.
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

## Privacy page

The options drawer opens **Privacy & data** as a full page. `PRIVACY_POLICY_URL`
defaults to an empty string. With no valid HTTPS URL, no WebView is created and
the page shows an unavailable notice plus the local data summary.

Configure the approved URL at build/run time with
`--dart-define=PRIVACY_POLICY_URL=<approved-https-url>`.
`webview_flutter` opens it inside the app, preserving existing query parameters
and setting `lang=en` or `lang=zh` for the current app language. No table content,
project identifiers, or account information is passed to the page. A loading
failure offers retry; the app bar returns to the workbench. Android declares
INTERNET permission for this optional flow; HTTPS needs no iOS ATS exception.
