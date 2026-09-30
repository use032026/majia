# 回声页 · EchoPage 证据登记

生成时间：2026-09-30T10:49:15+08:00

## 源码身份

项目不是 Git 仓库，不能提供 branch/SHA/dirty state。机械预检记录 `is_repository: false`。为避免伪造提交级可追溯性，使用质量门禁日志、时间戳和关键文件 SHA-256 作为有限替代证据；它们不能证明所有源码都未在构建后变化。

关键哈希示例：`pubspec.lock e6c2a3...c1b091`、`diary_repository.dart 84de16...d035`、`diary_entry.dart 159a48...60e7`、`home_shell.dart cdb5e1...1c1b`、`PrivacyInfo.xcprivacy 521eb6...60e7`。完整命令记录在本轮终端证据中。

## 证据层

| 层级 | 命令/设备/工件 | 结果 | 证明上限 | 原始证据 |
| --- | --- | --- | --- | --- |
| 静态 | Dart format + Flutter analyze | passed | 不证明运行态 | `evidence/automation/20260930T105552+0800/` |
| 自动化 | 32 domain/repository/controller/widget tests | passed | 不证明平台服务或真机 | 同上 `flutter-test.log` |
| iOS 模拟器 | iPhone SE 3rd、iPad 10th，iOS 18.3，Debug Simulator | inspected subset passed | 不证明实体设备/iOS 15 | `evidence/runtime/*.png` + 功能审核矩阵 |
| 视觉/交互 | 创建→问题→详情→Echo→关闭；中英、明暗、AX XXXL、iPad 空态 | inspected subset passed | 不覆盖所有状态、VoiceOver、横屏 | `FUNCTIONAL_REVIEW.md` |
| 实体设备 | 未执行 | not_run | 无真机结论 | 明确缺失 |
| Android 构建 | `flutter build apk --debug --no-pub` | passed | Debug APK 不是 Play 发布包 | `build/app/outputs/flutter-apk/app-debug.apk` |
| Android 运行 | 未执行 | not_run | 无 Android 设备/模拟器结论 | 明确缺失 |
| iOS Archive | `flutter build ipa --release --no-codesign --no-pub` | passed unsigned | 不证明签名、安装、上传或审核 | `build/ios/archive/Runner.xcarchive` |
| App Store Connect/TestFlight/App Review | 按用户要求未执行 | not_run | 无外部状态结论 | 预检报告 |

## 最终工件

| 工件 | SHA-256 | 大小 | 时间 | 限制 |
| --- | --- | ---: | --- | --- |
| Android Debug APK | `087894205711c1c6edb1fbd156673f469c167cd0abf62e3c79a1f4c16b8fe3d6` | 144,352,568 B | 10:48:14 +08:00 | Debug 签名，不可作为 Play release |
| iOS Archive App.framework/App | `07e0d61e01b576f5d335be0c18d6e8a17cd177e72bb54fe6750a335990366f0c` | 6,282,960 B | 10:56:24 +08:00 | 包含最终 Dart AOT 代码；Archive 未签名，无 provisioning profile |
| iPhone SE 关闭线索截图 | `8312492540f1ac76f1691c0a69e59311c0e8e1f37a5e4cab576437b106a06a28` | 107,069 B | 10:43:07 +08:00 | 内部运行证据，含 alpha，不是商店素材 |
| iPad 空态截图 | `d3d9ce65610a44f4e3bf9aa54e535e3df429611ae37580b38a2aa282f84b7975` | 162,658 B | 10:57:55 +08:00 | 最终源码 Simulator build；含 alpha，不是商店素材 |

## Archive 观察

- `CFBundleIdentifier=com.example.diary`（占位）；版本 `1.0.0 (1)`；最低 iOS `15.0`。
- Xcode `26.5`，SDK `iphoneos26.5`；架构 arm64；支持 iPhone/iPad。
- Embedded frameworks：`App.framework`、`Flutter.framework`、`path_provider_foundation.framework`。
- 主 App、Flutter、path_provider privacy manifests 均存在且可解析；Flutter 声明 File Timestamp/System Boot Time required-reason API。
- `codesign` 明确返回“code object is not signed at all”。

## 明确缺失

生产 Bundle ID/Team/Profile/签名、公开 Privacy/Support URL、法定主体与联系方式、App Store Connect 元数据/隐私回答/年龄分级、本地化商店素材、合规截图集、名称/商标清查、真机/最低系统/辅助功能/系统备份恢复、上传/处理/TestFlight/App Review。
