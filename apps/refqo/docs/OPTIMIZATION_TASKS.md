# Refqo interaction implementation — 2026-10-22

Mode: implementation. Coordinator, Planner, Executor and Reviewer are logical roles in this chat.
Scope: `apps/refqo` only. Keep the system keyboard; names and notes accept Chinese. No account, backend, release, commit or upload changes.

| Task | Executor scope | Acceptance | Evidence |
|---|---|---|---|
| RQ-01 | `lib/main.dart`, `lib/storage.dart` | Visible operation states; one writer; accurate success, failure and cancellation; safe partial-erasure recovery; next-step actions | Fault-injection and widget tests, source review |
| RQ-02 | `lib/editor.dart`, editor callers in `lib/main.dart` | Chinese composition preserved; Enter submits once; multiline Enter edits; Tab/arrows navigate without stealing selection; keyboard centering/restoration; pending saves protect navigation | Widget/key-event tests and simulator/emulator runtime |
| RQ-03 | Active-page rendering, forecast caching, ledger rendering | Build only current page; bounded first-feedback work; accessible loading/disabled/error states | Automated frame checks; runtime traces where available |
| RQ-04 | `test/`, `integration_test/`, `docs/release/` | Existing regressions plus closure/keyboard matrix; measured results separated from missing physical-device evidence | Analyzer, tests, named simulator/emulator runs, screenshots and acceptance report |

Dependencies: RQ-02 and RQ-03 depend on the operation contract in RQ-01; RQ-04 reviews all three.
Tests use this app's existing `test/` directory; no configured project-local ignored test directory exists. Runtime tests use disposable Refqo QA installations only.

100 ms means action dispatch to its first visible response. File-provider and OS-animation completion are recorded separately. A widget test is not a physical-device latency measurement.

## Coordinator result

- RQ-01: implemented; fault-injection, widget and real-file runtime paths passed.
- RQ-02: implemented; Chinese composition, wrapped-line focus, repeat deletion and geometry tests passed. Native system Pinyin candidate selection, software/hardware held deletion, focus keys, Enter and same-installation process restart passed on ordinary iPhone SE simulator main after host unlock.
- RQ-03: implemented; visible ledger entries built lazily; all three 30-save framework-feedback samples stayed below 100 ms. Physical presentation latency is unverified.
- RQ-04: analyzer/format/diff checks and 58 tests passed; iPhone SE, iPad mini and Android API35 runtime suites passed. Full physical-device/IME/OS/accessibility matrix is explicitly incomplete.

Reviewer revisions resolved: composing text cleared before submission, soft-wrap arrow boundaries, double-text keyboard-toolbar width, stale route-bound next actions, partial erase consistency, PageStorage key collision, and localized test back-button lookup.

See `docs/release/OPTIMIZATION_ACCEPTANCE.md` for acceptance boundaries and evidence.
