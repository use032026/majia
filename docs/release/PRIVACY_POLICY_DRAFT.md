# ReaderEdit Privacy Policy Draft

Status: local draft only. Before publication it requires the responsible legal entity, monitored contact, launch regions, final SDK inventory, Xcode Privacy Report and legal review.

Effective date: 2026-09-30

## Product and account model

- Product: ReaderEdit
- Account: none
- Backend: none; the app is designed to work offline
- Monetization: free, with no in-app purchases, advertising or subscription in this build

## Data handled by the app

ReaderEdit handles text the user creates, types, pastes, or explicitly selects through the system file picker: novel and chapter titles, chapter text, draft passages, reader promises, reader signals, notes and revised passages. It also stores language and appearance settings.

Selected TXT or Markdown content is decoded on-device and copied into ReaderEdit's local workspace. The original file remains under the operating system or file provider's control. These records are stored only inside the app sandbox on the device. The reviewed build contains no app-owned server, login, analytics, advertising SDK or telemetry code, and does not request runtime permissions. It does not intentionally transmit manuscript content to ReaderEdit or a third party.

ReaderEdit uses Flutter plus `file_selector`, `path_provider`, and `shared_preferences` for the interface, system file selection, and local storage. These are third-party software dependencies, not data recipients in the reviewed implementation. Their privacy manifests are present in the inspected iOS archive; this statement must be rechecked against the exact submitted archive and Xcode Privacy Report.

## Clipboard export

When the user explicitly taps Copy revised draft or Copy revision log, ReaderEdit writes that text to the system clipboard. After this action, the clipboard is controlled by the operating system and may be read or managed by other apps according to their permissions and policies. ReaderEdit does not read the clipboard in the reviewed build.

## Retention, recovery and deletion

Novels, chapters, and revision sessions remain in the app sandbox until the user deletes them, erases all local data, or removes the app. ReaderEdit maintains local primary, recovery and pending snapshots to protect against interrupted writes. A successful delete or erase operation replaces those snapshots with the post-deletion state, so deleted content is not retained by ReaderEdit's recovery files.

ReaderEdit does not offer an account or cloud deletion request because it holds no server-side account data. The user can delete an individual novel, chapter, or revision session, or use Settings & privacy → Erase all local data. Uninstalling the app is expected to remove its sandbox subject to operating-system backup/restore behavior, which is outside ReaderEdit's control.

## Collection, tracking and sharing

Based on the reviewed source and archive:

- ReaderEdit does not collect data on an app-owned server.
- ReaderEdit does not track users across apps or websites.
- ReaderEdit does not sell or share user data for advertising.
- ReaderEdit does not use account identifiers, location, contacts, camera, microphone or notifications.

These statements must be updated before release if any backend, SDK, diagnostic service, cloud backup feature or monetization component is added.

## Security and limitations

Local data benefits from the security controls of the user's device and app sandbox. No local-only design can guarantee protection if the device or operating-system account is compromised. Users should avoid placing highly sensitive information in any app unless they understand their device backup and clipboard settings.

## Contact and publication requirements

Before publication, add:

- responsible legal name and jurisdiction;
- monitored privacy/support email;
- stable public HTTPS privacy-policy URL;
- process for privacy questions and applicable legal rights;
- effective/updated dates and change notice process.
