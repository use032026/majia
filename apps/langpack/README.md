# 译包 LangPack · iOS / Android

独立的 Flutter 移动端工程，位于 `majia/apps/langpack/`，遵循每个马甲包一个目录的约定。支持中文和英文界面、文案输入、TXT / Markdown / DOCX 导入、目标语言多选、翻译任务、人工校对与 JSON / ZIP 导出，包含 App 图标、品牌启动画面和三步首次使用引导。

## 来源与维护范围

2026-11-02 从 [CherryIce/langpack-prototype](https://github.com/CherryIce/langpack-prototype) 的提交 [`dfb401cbeabcc5c8233f991d3410472ad28a6011`](https://github.com/CherryIce/langpack-prototype/commit/dfb401cbeabcc5c8233f991d3410472ad28a6011) 复制移动端快照。

**源仓库保留完整的 iOS、Android、Web 和桌面工程及其构建入口。** 本目录只维护 iOS / Android，不通过子模块或相邻检出目录引用源代码。两个仓库后续独立维护，需要同步的业务改动应明确移植。

逐文件来源、哈希与适配记录见 [`MIGRATION.json`](MIGRATION.json)。源提交中纳入本目录的文件共 109 个；除 `.metadata` 平台列表、测试输出目录和本目录忽略规则外，复制的业务代码、原生配置及资源均保持原样。

另带入源检出中现有的 `ios/Podfile.lock`：它原先受全局 Git 忽略规则影响，不属于上述源提交；其来源和 SHA-256 单独记录在清单中。本目录将该依赖锁文件纳入版本管理，供干净检出使用。未复制 Pods、构建缓存、安装包、环境凭据或签名材料。

## 工程身份

| 项目 | 当前值 |
| --- | --- |
| Flutter / Dart | 3.35.7 / 3.9.2 |
| Dart 包名 | `langpack` |
| iOS Bundle ID | `com.cherryice.langpack` |
| Android applicationId / namespace | `com.cherryice.langpack` |
| 应用版本 | `1.0.0+1` |

身份、版本、本地存储键、默认代理和现有图标 / 启动画面 / 引导页沿用源快照。复制源码不会把用户设备中的项目、校对记录或凭据同步到另一台设备。

## 本地开发

在本目录运行：

```sh
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <设备标识>
```

Android 调试包与无签名 iOS 模拟器构建：

```sh
flutter build apk --debug
flutter build ios --simulator --debug --no-codesign
```

iOS 构建需要 macOS、Xcode 和 CocoaPods。首次解析依赖后，可在 `ios/` 执行 `pod install`，再打开 `ios/Runner.xcworkspace`。Android 使用标准 Flutter / Android SDK 工具链；本目录不包含本机 SDK 路径或生成的 Gradle Wrapper 文件。

普通 `flutter test` 使用模拟响应。`test/live_smoke_test.dart` 中的真实服务测试默认关闭，只有明确传入 `RUN_LIVE_TRANSLATION` 或 `RUN_PUBLIC_PROXY_TEST` 才可能请求真实接口并消耗额度；其默认输出目录为本应用内忽略的 `artifacts/flutter-live/`。本次源码复制不代表构建、设备运行或真实服务验收已完成，验证结果以本次交付记录及对应 CI 运行结果为准。

## 翻译服务与本地数据

应用默认代理配置仍为 `https://langpack-standalone.406859116.workers.dev`。翻译代理继续由原项目维护，本目录不包含服务器代码；不需要在开发电脑保留原仓库检出。MyMemory 匿名模式可直接请求其接口，其他平台使用用户自行配置的凭据或经授权的开发者访问码，并通过代理转发。

原生客户端可在设置中填写自定义 HTTPS 服务根地址；构建定制首次默认地址时也可使用 `API_BASE_URL`。显式保存的应用内设置优先，清空后恢复内置默认代理。不要把真实密钥或开发者访问码写入源码、构建参数、日志或安装包。

文档在本地解析，开始翻译后所选原文会发送至对应服务。项目、译文、导出记录和设置保存在当前设备；凭据只在独立的会话或用户明确选择的本机保存区保留。设备之间和两个仓库之间没有自动数据同步。

## 品牌资源

`assets/brand/app-icon.svg` 与 `mark.svg` 是应用内的矢量母版。移动端资源生成工具位于 [`tool/generate-brand-assets.cjs`](tool/generate-brand-assets.cjs)：

```sh
node tool/generate-brand-assets.cjs
```

该工具需要调用环境已经提供 `sharp`，也支持通过 `NODE_PATH` 指定已有依赖目录。它只读取本应用母版并更新本应用的 Flutter PNG、iOS 图标 / 启动 PNG、Android 图标 / 启动 PNG，不访问网络，不写原仓库，不输出 Web 或桌面资源。Android adaptive / monochrome 矢量 XML 和启动主题随原生源码单独维护。

## 正式打包接入

现有 [`LangPack Mobile`](../../.github/workflows/langpack-mobile.yml) 继续负责检查、测试、Debug APK 和无签名 iOS 模拟器包。正式打包使用以下两个手动入口，保持身份 `com.cherryice.langpack`，签名材料由本应用独立配置。

### iOS 云打包

在仓库 **Settings → Environments** 创建 `langpack-production`，将部署分支限制为 `main`。以下配置全部放在这个 Environment 中；证书、描述文件和 ASC 密钥使用 LangPack 自己的材料，不复制其他马甲包的配置，也不在 Repository 层设置同名 iOS 凭据。

| 类型 | 配置名 | 内容 |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | LangPack 所属的 10 位 Apple Team ID |
| Variable | `IOS_BUNDLE_ID` | `com.cherryice.langpack` |
| Variable | `IOS_SCHEME` | `Runner` |
| Secret | `IOS_DISTRIBUTION_P12_BASE64` | 本应用分发证书及私钥导出的 P12，单行 Base64 |
| Secret | `IOS_DISTRIBUTION_P12_PASSWORD` | P12 密码 |
| Secret | `IOS_APPSTORE_PROFILE_BASE64` | 覆盖本应用 Bundle ID、团队和证书的 App Store 描述文件，Base64；也接受包含描述文件的 tar.gz 或 zip |

需要上传 App Store Connect 时，再在同一 Environment 配置 Variables `ASC_KEY_ID`、`ASC_ISSUER_ID` 和 Secret `ASC_API_KEY_P8`。仅打包无需 ASC 凭据。

进入 **Actions → LangPack iOS Release → Run workflow**，选择 `main`，填写三段式 `marketing_version`（默认 `1.0.0`）及可选 `build_number`。默认 `upload_to_asc=false`，只签名、导出并保留 IPA；启用上传后等待 ASC 处理结果。构建号留空时，仅打包使用 GitHub run number，上传时按 ASC 现有构建号递增。

工作流复用仓库固定版本的 iOS 云构建系统和 P12 兼容转换，签名 target 只有 `Runner`。IPA 等产物保留 30 天，运行摘要记录源码 SHA、构建号、IPA SHA-256 和 ASC 状态；不会自动创建商店版本、提交审核或修改商店文案和媒体。

### Android 正式打包

在仓库 **Settings → Secrets and variables → Actions → Secrets** 配置本应用专属的四项 Repository Secrets：

| Secret | 内容 |
| --- | --- |
| `LANGPACK_ANDROID_KEYSTORE_BASE64` | LangPack 独立 JKS / PKCS#12 文件的单行 Base64 |
| `LANGPACK_ANDROID_KEYSTORE_PASSWORD` | Keystore 密码 |
| `LANGPACK_ANDROID_KEY_ALIAS` | 本应用 key alias |
| `LANGPACK_ANDROID_KEY_PASSWORD` | 对应 key 密码 |

进入 **Actions → Android Package → Run workflow**，选择 `app=langpack`、`artifact=appbundle`（AAB）或 `apk`，保持 `sign_release=true`。版本名和构建号留空时使用 `pubspec.yaml`，也可通过 `version_name` 和 `build_number` 覆盖。正式签名缺少任一凭据即失败，不回退其他应用签名。

通用工作流只在 runner 上生成本应用的 `android/key.properties` 和 `android/app/release-keystore.jks`，Gradle 从本应用目录读取配置。APK / AAB 作为 Actions Artifact 保留 30 天，不自动上传 Google Play。本地正式打包同样需要本应用的 `android/key.properties`；`storeFile` 相对 `android/app/` 解析。签名创建、备份和验签步骤见 [Android 马甲包配置指南](../../docs/android-majia-configuration.md)。

`sign_release=false` 及未配置 `key.properties` 的本地 Release 构建沿用仓库内部验证约定，使用 debug key，不能作为商店包。不要提交签名文件、密码或 `key.properties`。

流程接入不代表签名材料已经配置或云构建已成功。专属 Debug / 模拟器构建、签名 IPA / APK / AAB、ASC 接收、TestFlight 可用和商店发布分别以对应证据为准。
