# ASTFX Privacy Policy

Status: local policy copy for the confirmed production domain [https://astfx1.com](https://astfx1.com). Policy URLs: [Simplified Chinese](https://astfx1.com/privacy.html?lang=zh) and [English](https://astfx1.com/privacy.html?lang=en). Public reachability is checked separately; hosting provider and log practices remain pending. The bilingual website policy at `website/privacy.html` is the complete release-material source.

Effective date: 2026-10-28

Operator: Independent developer (独立开发者)

Support and privacy contact: evwascr0317@icloud.com

ASTFX is a tabular-data quality workbench that processes imported tables on the device. It does not require an account and does not include advertising, analytics, tracking, cloud synchronization, or an application-operated backend.

## Data handled on the device

When the user chooses a CSV, TSV, TXT, or XLSX file through the operating system file picker, ASTFX reads that file for local processing. Text format and encoding or an Excel worksheet are confirmed before inspection. One project file in the app-private documents directory stores the source snapshot, current working copy, detected issues, and audit actions. The source file selected from the file provider is never overwritten.

The user can remove the local project in the app. Uninstalling the app also removes its private container according to operating-system behavior. A backup file is retained beside the current project only to recover from an interrupted local save, and is removed with the project.

## Export and sharing

When the user exports, ASTFX creates a CSV and Markdown report in a dedicated app temporary directory and passes them to the system share sheet. ASTFX attempts to delete both staged files when the share sheet returns and retries stale temporary-directory cleanup at the next app launch or export. A file leaves ASTFX only when the user chooses a share destination. The chosen destination then controls its own copy and privacy practices.

## Collection and network services

ASTFX does not transmit imported table content, audit actions, identifiers, diagnostics, or usage data to the developer. It does not track users across apps or websites. When the user opens Privacy & data, an in-app WebView requests `https://astfx1.com/privacy.html` by default with the current language (`lang=en` or `lang=zh`); it does not attach table content, project identifiers, or account information. With no valid URL configured, the app makes no policy-page request. The website host may receive IP addresses and request metadata. System backups and file providers follow their own settings and policies.

## Contact

Operator: Independent developer (独立开发者). Support and privacy questions: [evwascr0317@icloud.com](mailto:evwascr0317@icloud.com).
