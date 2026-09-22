# 微成 · Steady21 证据登记

冻结时间：2026-09-22T13:26:59+08:00

## 源码身份

本目录不是 Git 仓库，不能提供 branch/SHA/dirty state。替代冻结证据为：对 `lib test ios android`（排除 Pods 与 ephemeral）逐文件 SHA-256 后排序再哈希，结果 `5b1f04faa4bd7019bb75dd83e7970f18f8c009fddab324dc81e554106311617f`。`pubspec.yaml` 为 `9d3dfe8c4cf0ccb9a6ea62b97acb556acbfcd295c78cf899055b94a2f6d6ddb4`，`pubspec.lock` 为 `632c22f04f609de442b8df7d98c9dbc7703f158a5d7fbaa15e201cc5e5a5a43c`。

## 证据层

| 层级 | 命令/设备/工件 | 结果 | 证明上限 | 原始证据 |
| --- | --- | --- | --- | --- |
| 静态 | `dart format --set-exit-if-changed lib test`; `flutter analyze --no-pub` | passed | 不证明运行态 | `docs/release/evidence/automation/20260922T130811+0800/` |
| 自动化 | `flutter test --no-pub --reporter expanded` | 24 passed | 不证明平台集成或真机 | `flutter-test.log` 同上 |
| iOS 模拟器 | iPhone 16e `66CA4B43-2B31-447E-B592-88F37C58C8C7`；iPad Pro 11-inch (M4) `A993E4F6-54D5-4E68-98C6-FA0BFF5AA382`；iOS 18.3 | inspected | 只证明被操作页面和状态 | `docs/release/evidence/runtime/` |
| 视觉/交互 | 空状态、创建、记录、改正入口、设置中英/深浅色/大字、31 日报告顶部与尾部 | passed for inspected states | 不证明所有矩阵或读屏 | 三张 PNG + `RUNTIME_OBSERVATIONS.md` |
| 实体设备 | 未执行 | not_run | 无实体设备结论 | — |
| Android 构建 | `flutter build apk --debug --no-pub` | passed | Debug APK 不是 Play 发布候选；可能使用本地 debug keystore | `android-debug-build.log` |
| iOS Archive | `flutter build ipa --release --no-codesign --no-pub` | passed | 无签名 Archive 不证明安装、上传或 ASC 接受 | `ios-unsigned-archive.log` |
| 机械预检 | `flutter_release_preflight.py` | blocked | 机械扫描不替代 Apple 规则/外部状态审核 | `docs/release/evidence/automation/preflight-20260922T132538+0800/` |
| ASC/TestFlight/App Review | 未操作 | not_run | 未创建/上传/提交，符合停止条件 | — |

## 最终工件

| 工件 | SHA-256 | 大小 | 生成时间/限制 |
| --- | --- | ---: | --- |
| `build/app/outputs/flutter-apk/app-debug.apk` | `c3ee9a35db6b89578d9629fa08cc40253506c598fc2a2cf1d91901c2954475cd` | 144,487,426 B | 2026-09-22 13:08 +08:00；Debug only |
| `build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner` | `2aa50e0a9932a2de305a5f32378059cd0c099706085989df1562ac9af078c863` | 73,808 B | 2026-09-22 13:08 +08:00；未签名，哈希仅为主 executable |
| `docs/release/evidence/automation/20260922T130811+0800/quality-gate.json` | `834c9af642490c0b258950403533bffaa6e2c28f6ca529a9e11cd12d252e0542` | 3,188 B | 最终质量门禁机器记录 |
| `docs/release/evidence/automation/preflight-20260922T132538+0800/release-preflight.json` | `3e7fa8cf14130c47e7904bf406aec368830e2958d3cc116a6cb85bd88f320cfa` | — | 最终机械预检机器记录 |
| `docs/release/evidence/runtime/seed-ipad.json` | `7bb6f71ec7a22e420d39c734a7ff116cb86b6f4b5625ee1858ede489c8256776` | 5,006 B | 明确标注的运行压力种子，不随产品分发 |
| iPhone Today PNG | `455db9fb9d9b7cd330be70413e80809a40f6b65bfb3ebaf4e4d2ed48492672d7` | 283,204 B | 最终源码模拟器运行证据，不是商店截图 |
| iPad Journey top PNG | `7a11b669a45b7b83acf6f67a43cad745cf87f24f45fac25a45378edf4e65dabc` | 319,448 B | 最终源码模拟器运行证据，不是商店截图 |
| iPad Journey tail PNG | `0a2edfb27482cc7b8e0dd69df5aa082769c387d0bfc3598d15021dc23b80d2ee` | 459,603 B | 最终源码模拟器运行证据，不是商店截图 |

## 工具链与 Archive 身份

- Flutter 3.35.7 / Dart 3.9.2；Xcode 26.5 (17F42)，iOS 26.5 SDK。
- Archive：版本 1.0.0 (1)，最低 iOS 15.0，Bundle ID `com.example.steady21`，未签名、无 embedded provisioning profile。
- Archive frameworks：App.framework、Flutter.framework、path_provider_foundation.framework。
- 已解析隐私清单：Flutter.framework 与 path_provider_foundation；均声明无收集/跟踪，Flutter 声明 FileTimestamp 与 SystemBootTime required-reason API 理由。

## 明确缺失

- 生产 Bundle ID/Team/App ID/分发签名、最终原创图标和启动资产、公开隐私政策/支持 URL。
- App Store Connect App/版本、价格地区、分类、年龄分级、隐私问卷、审核联系人、中英文描述与合规截图。
- 最终 6.9-inch iPhone、13-inch iPad 无 alpha 商店截图；现有 PNG 尺寸/alpha 不合规。
- 实体设备、签名安装、Xcode Privacy Report、上传处理、TestFlight 与 App Review。
