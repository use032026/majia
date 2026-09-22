# 微成 · Steady21 App Review Notes Draft

Status: local draft; verify against the exact signed build and App Store Connect record. Do not submit this internal draft unchanged.

## Core purpose

Steady21 is an offline-first 21-day behavior experiment, not a claim that a habit forms in 21 days. A user defines one cue, a standard action, and a smaller minimum action; records a standard completion, minimum completion, or pause; chooses a gentle recovery strategy after a break; and reviews decisions at 7/14/21 practice days. The durable output is a local experiment report with daily observations, practice/streak statistics, common obstacles, recoveries, milestone decisions, and archived history.

## Reviewer path

1. Launch the app. No account, network connection, credentials, subscription, hardware, or permission is required.
2. On Today, choose “Create behavior experiment,” fill the four required text fields, keep or change the 21-day target, and save.
3. Record today as standard, minimum, or paused. Paused requires an obstacle and next-step plan. Correcting or undoing today’s entry is available from the same page.
4. Open Journey to inspect statistics, title stages, milestone reviews when thresholds are reached, and daily observations. Only one experiment is active; archive it to begin another while retaining the report.
5. Open Settings to switch Simplified Chinese/English, read the local-data and 21-day science boundaries, or delete all local experiments and entries.

## Account, backend, permissions, and purchases

- Account and demo credentials: none / not applicable.
- Backend: none. Core behavior and local records do not require a network connection.
- Sensitive permissions: none requested.
- Monetization: free; no IAP, subscription, advertising, donation, or external digital purchase link.
- Special hardware, entitlement, or region requirement: none in the reviewed MVP.

## Build-specific changes

- Initial Flutter MVP with local JSON persistence and save-before-commit failure behavior.
- Simplified Chinese and English UI, system light/dark mode, responsive phone/tablet layout.
- Behavior experiment creation/editing, daily observation and recovery, 7/14/21 milestone reviews, non-overlapping practice titles, full report, archive/restore/delete.
- 21 days is explicitly described as a starting/reflection milestone, not a guarantee of habit formation.

## Evidence boundary

Local functional review passed with 24 tests, simulator inspection, Android Debug build, and an unsigned iOS Archive. This draft does not claim physical-device, signed installation, upload processing, TestFlight, or App Review completion. Replace the working name, placeholder Bundle ID, default assets, internal “MVP candidate” wording, URL placeholders, and all build-specific statements before submission.
