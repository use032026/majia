# Somniloquy App Review Notes Draft

状态：本地草案；提交前必须与实际签名构建和 App Store Connect 记录逐项一致。

## Core purpose

Somniloquy is an offline-first night sound journal for adults who want to review private night sounds and morning memories without an account or medical score. It marks changes in volume against a local room baseline. Every candidate must be listened to and labeled or ignored by the user before it becomes part of a reviewed night card.

The app does not identify snoring disorders, apnea, sleep stages, disease, or sleep quality. It has no account, developer-operated backend, ads, analytics SDK, online AI, subscription, or in-app purchase.

## Reviewer path

1. Launch the app. The default language follows the saved in-app choice; Chinese and English can be selected in Settings.
2. On Tonight, optionally enter a memory prompt and select context tags, then tap Prepare to record.
3. Read the disclosure and confirm that any required consent from people sharing the room has been obtained. Microphone permission is requested only after this confirmation.
4. Record briefly. A visible recording state, elapsed time, current level and Stop action remain available. Recording automatically stops at 12 hours.
5. Stop and open Morning review. Listen to any candidate moments and explicitly label or ignore every candidate. Add an optional morning note, then save the night card.
6. Open Night cards to view reviewed cards and local context counts. Unreviewed drafts are kept outside the formal archive and can be resumed from Tonight.
7. Delete one card from its detail page, or delete all app-managed data from Settings. Each destructive action requires confirmation.

If microphone permission is denied, history and Settings remain available and the app explains how to retry. No demo credentials are required.

## Permissions and background behavior

- Microphone: records only after the user completes the in-app disclosure and starts a session.
- Background audio mode: supports the core overnight recording flow. The app instructs users to place the device on a stable, ventilated bedside surface, never under a pillow or mattress.
- No HealthKit, location, contacts, photos, notifications, tracking or account permissions are used.

## Data and privacy

Recordings, candidate timestamps, labels, prompts and notes are stored in the app sandbox and are not actively uploaded by the app. System device backup may include local app data if enabled. The app provides single-card and all-data deletion.

## Known submission prerequisites

Before using this draft, replace the placeholder Bundle ID, use the final signed Archive, add published privacy/support URLs, finish App Store Connect privacy and age-rating answers, attach final screenshots, and insert exact physical-device/OS evidence. Do not include internal file paths or this paragraph in the submitted notes.
