# Native checks — 2026-10-21 Asia/Shanghai
Normal production Dart entry `lib/main.dart`, Debug simulator build. Disposable Refqo QA iPad DF747168-3634-42B8-AD03-75E8F450306C, iOS18.3.
- Installed original icon observed in SpringBoard via CUA. Tapped icon; Chinese system locale first-run appeared. Native background and first Flutter screen share paper color; not a frame-by-frame transition capture.
- Skipped onboarding; relaunched normal app and reached product, without forced onboarding.
- Found P1: full-screen sharePositionOrigin left the iPad share content off-screen (UIAVC ready but only dismissal region visible). Replaced with 1×1 visible center anchor for both file and text shares.
- Rebuilt main app, opened backup share: native popover visible, JSON 107 bytes, Copy/Save to Files visible. Saved this empty QA library to On My iPad (not iCloud).
- Opened Restore native file picker; selected the saved JSON; Cupertino preview showed 0 supplies/0 appliances/0 ledger events. Confirmed; application displayed “备份已恢复。” No error banner.
- This native file roundtrip used an empty test library. Nonempty fidelity, malformed data, size limits and failure recovery are covered by domain/storage tests, not extrapolated from this screenshot.
Android normal main entry cold-launched on isolated API35 emulator; screenshot includes status/gesture bars. PAGE_SIZE=4096, so runtime is not evidence of a16KB environment. Remaining launcher-mask and native file-provider combinations are explicitly untested.

Final native retest: after successful restore, opened backup share again, dismissed by tapping outside, waited for Settings state, reopened and visually confirmed native JSON/Copy/Save panel, then dismissed again. No app error banner, resource exception or unintended library mutation was observed.
Original icon was observed installed on iPad. Android adaptive/legacy resources and native cold launch were checked; optional monochrome entry was removed because a full-background foreground is not a valid monochrome mask. Default colored icon remains original. Android launcher mask/themed-icon device matrix is not claimed.
