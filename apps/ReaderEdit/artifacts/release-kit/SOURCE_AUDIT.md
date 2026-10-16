# ReaderEdit material claims and source audit

Inspected: 2026-10-16 (Asia/Shanghai). Target only: `apps/ReaderEdit`, version `1.0.0+1`.

This run generated release materials and inspected implementation. It did not change application code. Historical release reports under `docs/release/` are prior evidence, not current build or Store status. All delivered screenshots were captured again on 2026-10-16.

| Claim or privacy topic | Current implementation evidence | Material treatment |
| --- | --- | --- |
| Local novels and chapters | `lib/domain/novel.dart`, `lib/app/reader_edit_store.dart:99`, `lib/ui/novel_detail_page.dart`, `lib/ui/chapter_reader_page.dart` | Create, read, and edit; no publishing claim. |
| TXT/Markdown import | `lib/data/text_import_service.dart:19`, `lib/domain/novel.dart:126` | System picker; 8 MiB byte limit, UTF-8 or BOM-marked UTF-16, supported Chinese/Markdown headings. No GBK/GB18030 claim. |
| Reader signals and revision queue | `lib/domain/revision_session.dart`, `lib/ui/scan_page.dart`, `lib/ui/revision_queue_page.dart` | User-supplied Clear/Dragging/Lost signals and notes, not automated AI or actual audience feedback. |
| Before/after and checks | `lib/ui/changes_page.dart`, `lib/ui/summary_page.dart` | Frozen originals, revised passages, reader-promise checks; no claim that revisions automatically modify a novel chapter. |
| Export | `lib/ui/summary_page.dart:186` | Explicit clipboard copy of revised draft or revision log, not document-file export or online publication. |
| Storage and recovery | `lib/main.dart:15`, `lib/data/session_repository.dart:51`, `lib/data/session_repository.dart:99` | App support directory, JSON primary/recovery/pending snapshots; preferences via shared_preferences. No encrypted-vault claim. |
| Deletion | `lib/app/reader_edit_store.dart:235`, `lib/app/reader_edit_store.dart:370`, `lib/data/session_repository.dart:110` | Successful deletion replaces recovery snapshots. Novel/chapter deletion leaves independent sessions. Clear-all preserves language/appearance/tour preferences. No forensic-erase guarantee. |
| Language, theme, tour | `lib/app/reader_edit_app.dart`, `lib/app/reader_edit_store.dart`, `lib/ui/onboarding_page.dart`, `lib/ui/settings_page.dart` | Chinese/English, light/dark, replayable tour. |
| Accounts, analytics, advertising, AI, backend, payments | Entire `lib/` import/call inventory plus `pubspec.yaml` and `pubspec.lock`; current UI | None implemented in the inspected app workflow. Dependency-host URLs in lockfiles are build infrastructure, not product network hosts. Negative statements are limited to inspected implementation. No traffic-interception or submitted-binary privacy conclusion. |
| Online privacy | `lib/config/privacy_policy_config.dart`, `lib/ui/privacy_policy_page.dart:40`, `lib/ui/privacy_policy_page.dart:73` | Empty by default; optional build-time HTTPS page; WebView JavaScript disabled. Do not claim fully network-free. |
| Permissions | iOS `Info.plist`, `PrivacyInfo.xcprivacy`, Android main manifest; aapt inspection of reused debug APK | INTERNET plus the AndroidX signature-only receiver permission. No camera/photos/mic/location/contacts/notification runtime request in app implementation. This is not a final release-artifact permission audit. |
| Backups/providers | App storage code and absence of app-managed sync; system file picker | System/provider backup and transfer behavior is conditional; no claim backups are disabled. |
| Website processing | Generated `website/site.js`, local HTML/assets/CSS | One local language preference; no external fonts, third-party images, analytics, or advertising scripts. Final hosting/logs remain unreviewed. |
| Operator/contact/domain/date | User explicitly answered “全部待定” on 2026-10-16 | All four stay empty in manifest. Pages explicitly identify a local draft. No invented legal identity, mailbox, domain, or effective date. |

## Rules refreshed

Official pages opened on 2026-10-16. The deterministic checks use the requested skill's current limits; website rule text is external reference material, not product claims.

- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/): current required iPhone Dynamic Island medium-display slot and 13-inch iPad slot; no alpha.
- [Apple version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information): 4,000-character description and 100-byte keywords; support URL must expose real contact information.
- [Google Play preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en): 80-character short description, 512px icon, 1024×500 feature graphic, phone screenshots and limited overlay text.

## Exact evidence boundaries

Simulator/emulator navigation is material-capture evidence. This run did not validate actual file-provider import, extreme text length, accessibility services, minimum supported OS versions, low storage, process-interruption recovery, network traffic, physical devices, final release manifests/SDK privacy reports, production URLs, legal wording, ownership/trademarks, signing, or distribution. Those remain separate release work.
