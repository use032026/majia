# Refqo product brief — 2026-10-21
Verdict: approved for local implementation. Free, offline, no account, English and Simplified Chinese.
Audience: households with several appliances sharing refill SKUs.
Problem: maintenance completion does not by itself answer how many compatible spares to buy for the next 30/60/90 days.
Loop: supply catalog → appliance links with user-confirmed fit → pooled demand less shared stock → receive stock → replace and deduct → chronological ledger and undo → share plan / backup / restore.
Non-goals: health/safety advice, automatic compatibility, manufacturer lifespan recommendations, reminders, commerce, cloud, photos, subscriptions.

## Architecture and acceptance
Supplies own part code, manual fit notes and shared stock. Appliance slots own interval in calendar days, last installation and manual fit confirmation. Receipt/replacement events record changes; latest event undo must be lossless. Forecast counts due occurrences inclusively, treats overdue as one immediate need, and recomputes all gaps after each change. No automatic equivalence between similarly named SKUs.
Local repository validates bounded schema and references, atomically persists before committing UI state, retains previous data, and locks normal writes on failed load. Restore parses and previews before explicit replacement; export via system share. No permissions before need.
Tabs: Plan (horizon, aggregate gaps and linked devices), Supplies (catalog, stocks, add/edit/detail, appliance links), Ledger (changes/undo), Settings (language, appearance, onboarding replay, privacy, export/import/delete).
Visual: warm paper background #FAF6F0; plum #493447; apricot #E9AA77; original refill-loop icon. Responsive centered content at max 760px. Font scale follows OS; wrapping text and scroll-end safe inset; Cupertino confirmations. Native launch is solid appearance-aware paper/plum with no text or delay. Onboarding is concise, localized, skippable, saved, replayable.
Acceptance: stock shared across 2 appliances is not counted twice; exact quantities for horizons; zero stock blocks replacement; edits/cancel do not mutate; save failure retains prior state and retry; malformed restore leaves current data; manual fit disclaimer; undo restores stock/date; long labels and large text reachable; clean/system/override/relaunch behavior; icon, native cold launch, first-run and returning launch inspected separately on iOS and Android.
Identity: Refqo (5 letters). Public exact-name queries returned no App Store or Play results; unpublished reservations and trademark clearance are unknown. com.example.refqo is a local placeholder and release blocker.
