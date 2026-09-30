# ReaderEdit App Review Notes Draft

Status: local draft. Verify every statement against the exact signed build and App Store Connect record before submission.

## Core purpose

ReaderEdit is an offline-first novel writing and revision workbench for independent writers. Users can create a local novel or import a TXT/Markdown manuscript, read it by chapter, switch directly into editing, and use a separate reader-perspective pass to locate where a passage feels clear, dragging or confusing.

This differs from writing/publishing platforms: ReaderEdit does not provide accounts, community, publishing, AI generation or cloud sync. Its durable output is a local workspace containing novels, editable chapters, and optional revision sessions with a frozen original, stable passage IDs, reader signals/notes, revised passages, completion state and copyable plain text.

## Reviewer path

1. Launch the app. No login, network connection or permission prompt is required.
2. Tap **Create novel / 创建小说**, enter a title, create a chapter, write text, and save. The chapter immediately returns to reading mode; tap **Edit / 编辑** to change it again.
3. Alternatively, tap **Import / 导入** and choose a UTF-8 or UTF-16 TXT/Markdown file. Common Chinese chapter headings and Markdown headings are converted into chapters. The selected content is copied into local app storage.
4. In a suitable chapter, tap **Start reader-perspective revision / 进入读者视角修订**, complete the three reader promises, and scan each passage as Clear, Dragging or Lost. Chapters outside the 2–80 passage / 30,000-character focused-revision boundary remain directly editable.
5. In Revision queue, revise a flagged passage, optionally resolve it, and use Review & export to verify promises and copy the revised draft or log.
6. Return home or relaunch to verify persistence. Delete an individual novel, chapter, or revision, or use Settings & privacy to erase all local data.

## Account, backend and purchases

- Account/demo credentials: N/A; there is no account system.
- Backend/network prerequisite: none.
- Runtime permissions: none.
- Purchases/subscriptions/advertising: none in this build.
- Hardware/region entitlement: none.

## Privacy and recovery behavior

Novels, chapters, drafts, signals, notes and revisions stay in local app storage. ReaderEdit uses primary/recovery/pending snapshots to survive interrupted writes. Successful deletion replaces recovery snapshots with the post-deletion state. If primary local data is invalid, the app opens the last valid local snapshot and shows a recovery notice rather than overwriting unreadable data.

## Changes in version 1.0.0

- Bilingual Chinese/English offline revision workflow.
- Local novel library, chapter creation, reading and direct editing.
- TXT/Markdown import through the system file picker with common heading-based chapter splitting.
- Frozen original and stable passage-level before/after history.
- Reader-signal queue with reassessment and reopen support.
- Reader-promise completion check and plain-text clipboard export.
- Local recovery protocol, per-session deletion and erase-all.
- Light/dark appearance and responsive phone/tablet layout.

## Evidence boundary

The local candidate was built with Xcode 26.5 / iOS 26.5 SDK and validated on an iOS 26.5 simulator. System Files presentation was observed, but selecting an actual external provider file was not completed in this review. The current archive is intentionally unsigned, uses a placeholder Bundle ID and was not uploaded. Replace all production identity and public URL placeholders, repeat the file-import/device matrix, and review these notes against the signed archive before using them in App Store Connect.
