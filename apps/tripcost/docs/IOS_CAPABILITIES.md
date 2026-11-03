# iOS 标识符与平台能力清单

> 正式标识于 2026-09-10 冻结。源码只保存非敏感标识；证书、描述文件、密码和 ASC API Key 只能由本地 Keychain 或受保护的 CI Environment 注入。

## 正式标识符

| 项目 | 正式值 | 状态边界 |
| --- | --- | --- |
| App 展示名 | RhinoSmart | 已写入 App 与 Widget 本地化资源；商店元数据仍以 ASC 为准 |
| Runner Bundle ID | `com.tripcost.lite` | 需在 Apple Developer 中确认 explicit App ID 和能力 |
| Widget Bundle ID | `com.tripcost.lite.widget` | 需独立的 explicit App ID 和 distribution profile |
| App Group | `group.com.tripcost.lite` | 需同时关联 Runner 与 Widget |
| CloudKit Container | `iCloud.com.tripcost.lite` | 需关联 Runner 并部署 Production Schema |
| Cloud build Team ID | `Z353FCBY9T` | 云端以实际 distribution profile 的 TeamIdentifier 为准 |
| ASC App ID | `6803728146` | 仅对应主 App；Widget 不创建独立 ASC App 记录 |

标识符集中放在 `ios/Config/Identifiers.xcconfig`，业务 Dart、路由、数据库表名和 Pigeon 契约不得读取或硬编码这些值。云构建配置使用相同的 Bundle ID，并在构建时注入 Team、证书和 profiles。

## Target 与最低系统

- Runner：iOS 15.0。
- AppWidget：iOS 15.0，SwiftUI + WidgetKit，不链接 Flutter Engine，不访问 Drift 数据库。
- RunnerTests / 后续原生测试 Target：iOS 15.0。

## Apple Developer Portal 与签名准备

1. 确认 Runner 与 Widget 均为上表中的 explicit App ID。
2. 确认 App Group 已关联 Runner 与 Widget。
3. 为 Runner 启用 iCloud/CloudKit 并关联正式 container；Widget 不直接访问 CloudKit。
4. 为 Runner 添加相机、相册用途文案；仅在对应功能实际触发时请求权限。
5. 为 Runner 与 Widget 分别生成 App Store Connect distribution profile；两份 profile 必须匹配 CI 使用的同一 Apple Distribution 证书。
6. 在 TestFlight 前部署 CloudKit Production Schema，并验证 record zone、subscriptions 和迁移流程。

## Release 能力边界

- Runner 的 Profile/Release entitlement 包含 App Group 和 CloudKit。
- Widget 仅包含 App Group，不直接声明 CloudKit。
- 当前不需要 Push Notifications、Background Modes、Sign in with Apple 或 Associated Domains。
- 云端配置会为 Runner 与 AppWidget 分别注入手动签名 profile；本地 Xcode 的开发 Team 不作为最终 IPA 的签名证据。
- 配置和 Archive 成功不证明 CloudKit、Widget 或 TestFlight 可用；这些能力仍需要真机、双设备和 ASC 状态证据。
