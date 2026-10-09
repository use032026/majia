# Android 通用打包

[`Android Package`](../.github/workflows/android-package.yml) 是所有已包含 Android 平台的 Flutter 马甲包共用的手动 GitHub Actions 工作流。它不使用 GitHub Environment，也不会上传 Google Play；运行结束后将 APK 或 AAB 作为 Actions Artifact 保留 30 天。

## 使用方法

在 GitHub 的 **Actions → Android Package → Run workflow** 中选择应用、产物类型和可选版本号/构建号。

- `apk`：生成可安装的 Release APK。
- `appbundle`：生成供 Google Play 上传的 Release AAB。
- `sign_release=true`（默认）：使用所选应用的独立签名凭据；缺少任何一项凭据时直接失败，绝不静默改为 debug 签名。
- `sign_release=false`：仅供内部验证。应用现有 Gradle 配置会使用 debug key 构建 Release 变体，不能上传商店。

## 每个应用的凭据

不需要创建 GitHub Environment。只需在仓库 **Settings → Secrets and variables → Actions → Secrets** 创建该应用对应的四个 Repository secrets：

| 应用 | 凭据前缀 |
| --- | --- |
| Diary | `DIARY` |
| ReaderEdit | `READEREDIT` |
| Somniloquy | `SOMNILOQUY` |
| CleanTrail | `CLEANTRAIL` |
| LAURUS / Hearthio | `HEARTHIO` |
| looters | `LOOTERS` |
| Jufu | `PHOTO` |
| PlotProof Lab | `PLOTPROOF_LAB` |
| KIFXPRO | `SDPACKET` |
| Steady21 | `STEADY21` |
| Trip Delta | `TRIP_DELTA` |

以 Jufu 为例，需要创建：

```text
PHOTO_ANDROID_KEYSTORE_BASE64
PHOTO_ANDROID_KEYSTORE_PASSWORD
PHOTO_ANDROID_KEY_ALIAS
PHOTO_ANDROID_KEY_PASSWORD
```

`*_ANDROID_KEYSTORE_BASE64` 是 JKS 或 PKCS#12 文件的单行 Base64 内容。macOS 可用 `base64 -i release.jks | tr -d '\n'` 生成；不要提交 `key.properties`、`.jks`、`.keystore`、`.p12` 或任何密码到仓库。

应用清单和凭据前缀维护在 [`.github/android-packages.json`](../.github/android-packages.json)。新增 Android 马甲包时，先确保它有 `android/` 平台，再登记路径、显示名称、包名和新的凭据前缀。已有马甲的验签、新马甲的签名创建、接入工作流和常见故障处理见 [Android 马甲包配置指南](android-majia-configuration.md)。

## 当前范围

已覆盖 11 个已有 Android 工程的 Flutter 应用。`PhotoReport` 与 `TripCost` 当前没有 Android 工程，因此不能由此工作流打包；为它们生成 Android 平台并完成包名、图标和签名配置后再加入清单。

许多现有工程仍使用 `com.example.*` 占位 Application ID。工作流可以构建，但这类应用在注册正式包名、配置 Play Console 和验证签名身份之前，不应视作可发布的商店构建。
