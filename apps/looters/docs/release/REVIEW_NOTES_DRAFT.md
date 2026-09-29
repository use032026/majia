# PaceJar · 节奏罐 App Review Notes Draft

状态：本地草案。提交前须以最终签名构建和 App Store Connect 记录逐项复核，不应把内部证据路径复制到审核备注。

## Purpose and product boundary

PaceJar is an offline-first manual savings planner for people with variable income. It compares a plan with manually recorded progress, then offers transparent recovery choices while preserving earlier plan versions. It does not connect to banks, move or hold funds, automate transfers, provide financial advice, or promise returns.

There is no account, login, backend, subscription, in-app purchase, advertising, analytics, or demo credential. No network or regional prerequisite is required for the core workflow. The app requests no sensitive system permission. Copy recap writes plain text to the clipboard only after an explicit user tap.

## Reviewer path

1. On first launch, tap **Create a focus goal**. Enter a name, currency symbol, target amount, current saved amount, a future target date, and an affordable weekly amount, then save.
2. On the Pace tab, inspect the separately labeled planned and actual tracks. Tap **Record this week** and choose Saved, Withdrawn, or Skipped. Save the event.
3. If progress is behind plan, open **View recovery options**. Compare Keep date, Keep weekly amount, and Custom weekly amount. Confirming a valid choice appends a new plan version; it does not rewrite earlier events or plans. For an expired target, Keep date is intentionally disabled.
4. Open Timeline to view events and plan versions together. Tap **Copy recap** to place a plain-text summary on the clipboard.
5. Open Settings to switch between English and Simplified Chinese or light/dark appearance. **Delete all data** requires a destructive confirmation and removes the current goal, events, and plan versions.
6. To test completion, record enough Saved value to reach the target. The completed view offers the recap and an explicitly destructive Start new goal flow.

## Failure and recovery behavior

- Invalid amounts, a withdrawal above the current balance, past target dates, and non-positive weekly amounts are rejected before saving.
- A storage write failure leaves the last committed data unchanged and offers retry/cancel behavior.
- Corrupt or unsupported local data is isolated behind a recovery screen and is never silently overwritten; the user must explicitly clear it.
- A normal storage read failure is write-locked and offers Retry so that an apparently empty screen cannot overwrite existing data.

## Changes in version 1.0.0 (build 1)

- One-focus-goal creation with integer-cent amount storage.
- Manual Saved, Withdrawn, and Skipped events.
- Planned-versus-actual pace view and recovery previews.
- Append-only plan-version timeline and copyable bilingual recap.
- Offline persistence, explicit corrupt-data recovery, and delete-all confirmation.
- English/Simplified Chinese, light/dark appearance, and responsive iPhone/iPad layout.

## Evidence boundary and release prerequisites

Local validation used Flutter 3.35.7, an iOS 26.5 iPhone 17 Pro Max simulator, and an iOS 26.5 iPad Pro 13-inch simulator. Unit/widget tests, a debug Android APK, and an unsigned iOS archive passed local gates. Physical-device, VoiceOver/TalkBack, minimum-iOS, final signing, TestFlight, App Store upload, and review have not been performed.

This draft cannot be submitted unchanged: `com.example.paceJar` is a placeholder Bundle ID, the archive is unsigned, and final Privacy Policy URL, Support URL, legal entity, contact details, store metadata, name/trademark clearance, and App Store privacy answers are still required.
