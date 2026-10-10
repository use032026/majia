# Almanac App Review Notes Draft

Status: local draft. Verify against the exact signed build and current App Store Connect record before use.

## Core purpose

Almanac is a bilingual, offline-first daily reflection tool inspired by the concise “宜/忌” form of traditional almanacs. It is not divination, fortune telling, auspicious-date advice, a complete calendar, or a book reader. It does not provide lunar-calendar facts, solar terms, luck scores, predictions, medical advice, or financial advice.

The durable user loop is: read one locally composed daily leaf → choose one Try and one Skip → optionally write an intention → seal the leaf → reflect as Practiced, Reframed, or Released → retain it in the local Folio → optionally copy the folio as Markdown.

## Reviewer path

1. Launch the app. The first screen explains the non-prediction and local-data boundaries.
2. Tap **Open today's leaf**.
3. Select one item under **Try** and one under **Skip**. The seal button remains disabled until both are selected.
4. Optionally enter an intention, then tap **Seal today's leaf**.
5. Tap **Reflect on today** and choose one of the three non-judgmental outcomes. Dismissing the sheet makes no change.
6. Open **Folio** to inspect the durable entry and its detail sheet.
7. Open **Settings** to switch Chinese/English and light/dark appearance, copy the folio as Markdown, read the local privacy/content method, or clear all daily leaves after confirmation.

The same installation and local date produce stable content; language changes do not change the underlying content IDs. On a date change, the app creates a new leaf and asks the user to reselect rather than applying a prior day's choices.

## Account, backend, permissions, and purchases

- Account or login: none; no credentials are needed.
- Developer backend/network requirement: none. Core functionality works offline.
- Runtime permissions: none.
- Ads, analytics, subscriptions, IAP, or paid content: none.
- External hardware, region setup, or entitlements: none for the core flow.

## Local data and deletion

Choices, optional intentions, reflections, preferences, and an installation seed are stored locally. Failed writes do not replace the prior state. Invalid stored data enters a non-destructive recovery screen. **Clear all daily leaves** deletes app-managed records after confirmation while keeping language, appearance, and the installation seed. System backups and user-initiated clipboard copies are explained in the app.

## Changes in build 1.0.0 (1)

- Original deterministic bilingual daily prompt and verse generator.
- Try/Skip selection, optional intention, seal, and reflection workflow.
- Local Folio with detail view and Markdown copy.
- Chinese/English and system/light/dark preferences.
- Local recovery, write-failure feedback, confirmed deletion, and date-rollover handling.
- In-app privacy and content-method disclosures.

## Evidence boundary and pre-submission replacement list

Local validation used iPhone 16 Pro and iPad Pro 11-inch simulators on iOS 18.3, Android API 35, 23 automated tests, and an unsigned Xcode 26.5 / iOS SDK 26.5 archive. Before submitting these notes, replace this paragraph with the exact signed archive identity, physical-device results, final Bundle ID, privacy/support URLs, and any known limitations. Remove internal file paths and confirm the final binary still contains no account, network backend, ads, analytics, permissions, or purchases.
