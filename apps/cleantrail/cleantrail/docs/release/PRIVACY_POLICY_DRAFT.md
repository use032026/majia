# CleanTrail Privacy Policy Draft

Status: local draft only. A public HTTPS version and its final legal owner/contact must be supplied before App Store submission.

Effective date: 2026-09-08

CleanTrail is an offline-first tabular-data quality workbench. It does not require an account and does not include advertising, analytics, tracking, cloud synchronization, or an application-operated backend.

## Data handled on the device

When the user chooses a CSV, TSV, TXT, or XLSX file through the operating system file picker, CleanTrail reads that file for local processing. Text format and encoding or an Excel worksheet are confirmed before inspection. One project file in the app-private documents directory stores the source snapshot, current working copy, detected issues, and audit actions. The source file selected from the file provider is never overwritten.

The user can remove the local project in the app. Uninstalling the app also removes its private container according to operating-system behavior. A backup file is retained beside the current project only to recover from an interrupted local save, and is removed with the project.

## Export and sharing

When the user exports, CleanTrail creates a CSV and Markdown report in a dedicated app temporary directory and passes them to the system share sheet. CleanTrail attempts to delete both staged files when the share sheet returns and retries stale temporary-directory cleanup at the next app launch or export. A file leaves CleanTrail only when the user chooses a share destination. The chosen destination then controls its own copy and privacy practices.

## Collection and tracking

CleanTrail does not transmit imported table content, audit actions, identifiers, diagnostics, or usage data to the developer. It does not track users across apps or websites.

## Contact

Before publication, replace this section with the developer's legal name and monitored support/privacy email, then publish the policy at a stable HTTPS URL.
