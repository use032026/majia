# 回声页 · EchoPage App Review Notes Draft

Status: local draft only. Replace the working name, URLs, identity and build facts against the exact submitted binary before use.

## Core purpose

EchoPage is an offline reflection diary for people who write in the moment but rarely return to see how their thinking changed. A page can contain a question for the user's future self. On revisit, the user rereads the original page, writes an Echo, marks the change in perspective, then closes the thread or schedules another revisit.

The durable output is a searchable before/after reflection thread stored in the app sandbox. The app does not send diary content to a developer service. Device/cloud backup, migration and restore at the operating-system level may include sandbox data depending on the platform and user settings.

## Reviewer path

1. Launch the app; no account, network, permission, purchase or demo credential is required.
2. On **Now**, tap **Capture this moment**. Enter a page body and an optional question for the future; choose 3 days, 1 week or 1 month and save.
3. Open the saved page. Tap **Add an Echo**, write what happened, select a perspective marker, then either close the thread or keep it open for 7 more days.
4. Open **Threads** to search title, body, question and Echo text, and filter Waiting/Closed.
5. From a page menu, copy the complete before/after record or move it to Recently Deleted. Settings contains restore/permanent-delete actions and the local privacy summary.

## Account, backend, permissions and payments

- No account or login.
- No developer backend, analytics, ads, tracking or remote configuration.
- No runtime permissions.
- Free; no in-app purchases or subscriptions.
- No special hardware or region prerequisite for core functionality.

## Changes in this build

- Adds the complete page→future question→scheduled revisit→Echo→close/continue workflow.
- Adds bilingual Chinese/English UI, light/dark/system appearance and iPhone/iPad responsive layout.
- Adds local atomic persistence, readable-backup recovery, locked editing when both files are unreadable, Recently Deleted and in-app backup sanitization on permanent deletion.
- Adds full-record clipboard copy and explicit clipboard/storage failure feedback.

## Privacy and deletion boundary

Permanent delete and Clear All remove selected content from the current installation and its in-app current/pending/backup files. Historical device/iCloud/Google system backups may still contain older copies; these are controlled by the operating system and user settings and cannot be accessed or deleted by the developer.

## Evidence boundary before submission

Current local evidence used iPhone SE (3rd generation) and iPad (10th generation) simulators on iOS 18.3 plus an unsigned Xcode 26.5/iOS 26.5 SDK Archive. This draft must not be submitted until a signed production candidate, real-device checks, public Privacy/Support URLs, final App Store metadata and exact screenshot sets exist.
