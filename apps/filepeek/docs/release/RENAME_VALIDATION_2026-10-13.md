# FileRecheck 更名验证（2026-10-13）

> 历史更名快照：同日后续范围调整已移除文件分享导入、iOS 分享扩展及 App Group。下述扩展构建记录仅对应移除前的构建，不能描述当前版本。

## 当前范围与验证

- 用户决定仅保留应用内系统文件选择器导入；主动导出副本和报告仍使用系统分享界面。
- 已从 Flutter 代码和依赖、Android `ACTION_SEND` 入口、iOS 分享扩展及 App Group 配置移除分享入站链路。
- `flutter analyze --no-pub` 无问题，`flutter test --no-pub` 30 项通过；iOS 模拟器与 Android debug 包重新构建成功。
- 清理旧构建产物后，iOS `Runner.app` 不含 `.appex`；Android APK 的 Manifest 没有 `ACTION_SEND` 入口。
- iPhone 17 Pro / iOS 26.5 模拟器中，从“打开文件”进入系统文件选择器，选入 `check.json` 后显示文件内容和“检查通过”。

## 更名时的历史配置

本次将当前产品显示名、Flutter 包名、iOS 主应用及分享扩展、Android 包名、App Group 配置、分享通道和当前文案改为 FileRecheck。仓库目录 `apps/filepeek` 保留，便于追踪已有历史记录；2026-10-12 的审核与自动化证据仍对应旧构建。

## 已验证

- `flutter analyze --no-pub` 无问题，`flutter test --no-pub` 35 项通过。
- iPhone 17 Pro / iOS 26.5 模拟器运行后，首页标题为 FileRecheck；安装的主应用 ID 为 `com.example.filerecheck`，内嵌扩展 ID 为 `com.example.filerecheck.FileRecheckShareExtension`。
- iOS 模拟器 Xcode Debug 构建成功，主应用与扩展生成的模拟器 entitlements 均指向 `group.com.example.filerecheck`。
- Android debug APK 构建成功；APK 的包名、桌面标签及入口 Activity 分别为 `com.example.filerecheck`、`FileRecheck`、`com.example.filerecheck.MainActivity`。

## 仍需验证

- 更名后尚未完成从 iOS Files 分享文件到扩展、再由主应用读取的端到端实测。模拟器构建产物的实际临时签名未包含 App Group entitlement，不能仅凭构建成功认定分享导入可用；最终签名包及真机需再核对。
- `com.example.filerecheck` 和 `group.com.example.filerecheck` 仍是开发占位。正式身份、目标地区名称及商标可用性、商店材料和发布签名仍待确认。
