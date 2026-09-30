# ReaderEdit 证据登记

生成时间：2026-09-30T12:01:40+08:00

## 源码身份

当前目录不是 Git 仓库，因此没有 commit/branch 证据。对 `pubspec.yaml`、`pubspec.lock`、`lib/`、`test/`、`ios/`、`android/` 中受审源码/配置文件按路径排序后逐文件 SHA-256，再聚合得到快照指纹；排除 Pods、`.symlinks`、Flutter ephemeral、Gradle 缓存和 `.cxx`：

`cb08e7ac7dda8a434e2b0afc808e814a0149aaefc5fb2b7c92c8f2d948c2b9c5`

该指纹不具备 Git 历史、作者、分支或可重现 checkout 证明力。

## 证据层

| 层级 | 命令/设备/工件 | 结果 | 证明上限 | 原始证据路径 |
| --- | --- | --- | --- | --- |
| 静态 | Dart format + Flutter analyze | passed | 不证明运行态 | `docs/release/evidence/automation/20260930T120051+0800/` |
| 自动化 | `flutter test --no-pub --reporter expanded` | passed，29 tests | 文件选择器内容由 fake 注入，不证明真实文件提供方 | `flutter-test.log` |
| Android 构建 | debug APK，min SDK 24 | passed | Debug APK 不等于 Play release 或设备运行 | `android-debug-build.log` |
| iOS 构建 | `flutter build ipa --release --no-codesign` | passed；unsigned archive | 不证明签名、安装、上传或 TestFlight | `ios-unsigned-archive.log` |
| iOS 模拟器 | iPhone 17e / iOS 26.5 | passed for inspected states | 证明创建小说/章节、阅读编辑、重启持久化和 Files 选择器展示；未选择真实文件 | `docs/release/evidence/runtime/iphone17e-chapter-read-zh-light.png` + 本轮 AX/截图记录 |
| 旧 UI 矩阵 | iPhone 17e/17 Pro Max、iPad Air 11 / iPad Pro 13，iOS 26.5 | partial_stale | 原修订页证据仍有效；首页截图早于书架改版，不能代表当前候选 | `docs/release/evidence/runtime/` |
| 实体设备 | 未运行 | not_run | 无真机、最低 iOS 或真实文件提供方结论 | — |
| ASC/TestFlight/App Review | 未上传（按停止条件） | not_run | 无外部状态结论 | — |

## 自动化与机械预检

- 最终质量门禁：`docs/release/evidence/automation/20260930T120051+0800/QUALITY_GATE.md`，`passed`。
- 最终机械预检：`docs/release/evidence/automation/preflight-20260930T120134+0800/RELEASE_PREFLIGHT.md`，`blocked`。
- 机械通过：App Icon、archive info、privacy manifests、版本/身份一致性、旧截图尺寸/alpha、请求工件存在。
- 机械阻断：placeholder Bundle ID、Privacy URL、Support URL、签名/profile。
- Archive 新增并发现 `file_selector_ios.framework` privacy manifest。

## 最终工件

| 工件 | SHA-256 | 大小 | 生成时间 | 限制 |
| --- | --- | ---: | --- | --- |
| 原始品牌图 | `01d7dab3abec7bd12b11a3ae33f93a56387d23799bb0afb13c00c381551f3bc2` | 1,657,046 | 2026-09-30 09:49 +08 | AI 生成，仍需商标检索 |
| Android debug APK | `22d7e52adb3e264e6091036bd4341e470e84c73e1e4b86b074d846e3fbad0f6d` | 163,846,990 | 2026-09-30 12:01 +08 | 非 Play release；min SDK 24 |
| iOS archive executable | `c4f5f1138a972f06682263ee8b11ad3e94b8fa6eca85cf88414a9ce2d6bc3d9b` | 74,112 | 2026-09-30 12:01 +08 | archive 未签名、无 profile |
| iPhone 17e 章节阅读运行态图 | `eaf9dd38169d0a349dc99cd1dceb61c31cb075f782e18d81fd196b437e96ca9d` | 152,795 | 2026-09-30 11:43 +08 | 运行态证据，1170×2532 RGBA，不是商店候选 |
| 旧 6.9-inch 首页截图 | `01a4a72450e8fac15e471122597e92d4a7aa2ac7824ba43539596cebc80a69a7` | 677,938 | 2026-09-30 10:22 +08 | 尺寸/alpha 合规但内容早于书架改版，必须重拍 |
| 旧 13-inch iPad 首页截图 | `cef778669ead4712df47f8d4c2e01642c53459dece2d2bb322f65c32309a7cab` | 466,641 | 2026-09-30 10:28 +08 | 尺寸/alpha 合规但内容早于书架改版，必须重拍 |

## 明确缺失

- 生产 Bundle ID、Apple Team、App Store distribution profile 与有效签名。
- 公开隐私政策/支持 URL、法定主体/联系邮箱、ASC metadata 与隐私回答。
- 当前书架/导入/章节阅读编辑/读者修订的完整 iPhone/iPad 双语商店截图组。
- 实际 Files/iCloud/第三方文件提供方导入、极限长文性能、实体设备、最低 iOS 15、Android 7.0 设备、无障碍、低存储和进程中断。
- 上传、处理、TestFlight 与 App Review（未执行）。
