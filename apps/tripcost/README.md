# RhinoSmart

RhinoSmart 是旅行真实消费成本助手（项目目录为 `apps/tripcost`，开发代号为 TripCost）。Flutter 主应用支持 iOS 15+ 与 Android 24+；已具备精确金额、Drift、Frankfurter v2 与离线汇率链路、快速换算、支付成本与 DCC，以及行程 CRUD、预算仪表盘、消费账本、实际入账和本地费用校准。历史汇率与支付规则均以快照随消费保存。iCloud 与 Widget 仅在 Apple 平台启用；Android OCR 使用随包分发的本机模型。

## 本地启动

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter run -d <ios-simulator-id>
```

Android 使用正式包名 `com.tripcost.lite`。云端 APK/AAB 由仓库根目录的 `Android Package` 工作流生成；没有 `TRIPCOST_ANDROID_*` 正式签名 Secrets 时，只能以 `sign_release=false` 生成内部验证包。

iOS 本地 Xcode 16.2 构建将 `connectivity_plus` 固定在 6.1.x；7.3.x 的 iOS 源码引用了该 SDK 尚未提供的 `NWPath.isUltraConstrained`，升级依赖前需先核对 Xcode SDK。

环境参数通过 `--dart-define` 注入：

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=API_BASE_URL=https://api.frankfurter.dev
```

## 生成 Pigeon 契约

```bash
./tool/generate_pigeon.sh
```

提交 schema 与 Dart/Swift 生成产物。中英文显示名统一为 RhinoSmart，Apple 标识保持现有值；能力、签名材料和人工验收边界见 `docs/IOS_CAPABILITIES.md`。

## iOS 云构建

仓库通过手动触发的 `RhinoSmart iOS Release` GitHub Actions 工作流归档 Runner 和 AppWidget。工作流默认不上传 App Store Connect；生产签名材料只存放在受保护的 `tripcost-production` Environment 中。

- 构建配置：`.github/ios-build.yml`
- 工作流：[`../../.github/workflows/tripcost-ios-release.yml`](../../.github/workflows/tripcost-ios-release.yml)
- 首次验证：使用 `upload_to_asc=false`，并核对远端 SHA、IPA 中的两个 Bundle ID、签名 Team 和 embedded profiles。
- 正式上传：确认使用未占用的 build number 后，再使用 `upload_to_asc=true`。

## 生成数据库代码与 schema

```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump \
  lib/core/storage/database/app_database.dart \
  drift_schemas/
dart run drift_dev schema generate \
  drift_schemas/ \
  test/generated_migrations/
```

每次提升 `AppDatabase.schemaVersion` 时同时提交新 schema 导出、显式升级步骤和旧版本迁移测试。

## 汇率网络冒烟

默认测试不会访问公网。需要单独验证 Frankfurter v2 的币种、批量和历史接口时运行：

```bash
RUN_FRANKFURTER_SMOKE=1 \
  flutter test test/core/rates/data/frankfurter_live_smoke_test.dart
```

连接类型只用于执行“仅 Wi-Fi”策略，不能证明互联网一定可用；实际请求仍通过超时、错误映射、缓存回退和指数退避处理失败。

## Online privacy policy

All online pages on iOS and Android use the shared app Web launcher and
`stmini_flutter`'s `mini_web` container. The privacy-policy button keeps the
existing `https://tripcost.fit/privacy.html?lang=zh|en` address and app language.
The repository-relative package in `packages/stmini_flutter` is an unchanged
snapshot of the `mini_web` source at the commit recorded in `UPSTREAM.json`.

Initialization and loading happen after an explicit page-opening action, or on
cold start after the opt-in described below. Web startup hides the native
navigation bar. The privacy page shows it so a root iOS WebView has a close
button and an Android WebView has a back button; its page content may also
show its own HTML header. Pushed iOS pages keep the upstream navigation-stack
edge gesture. Loading failures follow the upstream WebView
behavior. The app no longer uses a separate iOS privacy WebView or Android
browser route. Failure to present the container uses the existing Flutter
failure message. No unrelated network probe is added.

## Opt-in Web startup

TripCost's `AppWebLauncher` registers the host handler before initializing the
`mini_web` runtime. The plugin handles `getUserInfo`, `getToken`, and Web
storage requests using the shared auth and profile storage keys. The host
handles H5 `open`, `close`, and `web_notifySessionChanged`: `/web` opens a new
HTTPS WebView, while an H5 internal route such as `/login` opens a child
WebView with the route payload in `__mini_open_route`. Login children carry
`isBack=1`, so a successful login can return to the originating page. H5
`close` pops that child or closes the root. Session changes notify the other
open Web pages to refresh their own auth state. Diagnostic `applog` calls are
acknowledged.

The host accepts bridge calls only from a native-verified HTTPS top-level
document and opens only HTTPS `/web` links. HTTP remains disabled. These are
ordinary Web capabilities on iOS and Android; TripCost does not enable Mini
package updates or Mini package page-stack APIs. The startup URL and privacy
policy URL are unchanged.

On the Settings screen, hold exactly three touch fingers stationary for five
seconds. Timing starts when the third finger touches. Releasing/cancelling a
finger, moving beyond the touch tolerance, adding a fourth finger, leaving the
screen, or backgrounding the app cancels the hold. All fingers must be released
before another attempt. Normal single-finger scrolling and navigation keep their
existing behavior.

Activation first saves the independent local preference
`startup.polymer_web_enabled.v1`, then opens
`https://h5.globalsmartchoose.com/polymer/h5app/#/` through the existing
`AppWebLauncher` and `mini_web` container. There is no confirmation or additional
mode control. A preference-write failure prevents opening and offers Retry.

Once enabled, later cold starts present that same online page while the launch
mark is still mounted, before navigating to the existing Home/onboarding fallback
behind the native container. This is an intentional startup-network exception to
the default tap-only online-page behavior. Closing the container reveals the
native app; the preference stays enabled. Resuming an already-running app does
not reopen the page. Presentation failure falls back to native UI and offers
Retry without disabling the saved mode. Network or document-loading failures
follow the unchanged `mini_web` container behavior.
