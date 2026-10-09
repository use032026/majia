# Android 马甲包配置指南

本指南说明如何让一个 Flutter 马甲包接入仓库的 [`Android Package`](../.github/workflows/android-package.yml) 工作流。该工作流只构建并保留 APK/AAB Artifact，不会自动上传 Google Play。

适用两种情况：

- **已有马甲**：已经发布过或已有历史 APK/AAB，必须延续原有签名才能更新同一 Google Play 应用。
- **新建马甲**：还没有 Android 发布身份，需要先确定包名并创建独立签名。

## 基本原则

- 每个马甲有唯一的 Android Application ID、签名 keystore 和 Secret 前缀，绝不共用或提交密码。
- 历史应用的签名证书不可替换。若使用不同 JKS 签名，即使应用名称相同，也不能更新原有商店应用。
- JKS、P12、`key.properties`、Base64 内容和密码不得提交到 Git，也不要发到聊天或截图中。
- GitHub 不会在保存后回显 Secret 内容；编辑页面显示为空是正常的安全行为。

## A. 接入已有马甲

### 1. 确认发布身份

记录该应用的以下信息：

- Android Application ID（Google Play Console 中的包名）；
- 原始签名文件（JKS/P12）、keystore 密码、key alias 和 alias 密码；
- 一份已经签名的历史 APK/AAB（如果有）。

必须先确认源码里的 `applicationId` 与商店包名相同。不要把 `com.example.*` 当作商店正式包名。

### 2. 验证签名是否属于该马甲

将历史 AAB 与准备使用的 JKS 比较证书 SHA-256 指纹。以下命令只输出指纹，不打印密码：

```sh
# 从 key.properties 读取 storePassword、keyAlias，导出 JKS 证书后查看指纹。
keytool -exportcert -keystore upload-keystore.jks -alias YOUR_ALIAS -rfc \
  | keytool -printcert

# 查看历史 AAB 的签名证书指纹。
keytool -printcert -jarfile app-release.aab
```

两者的 SHA-256 指纹一致，才可把该 JKS 用于这个已有马甲。若不一致，停止配置并查找该应用原始签名。

### 3. 写入 GitHub Repository Secrets

在仓库 **Settings → Secrets and variables → Actions** 中，为该马甲前缀创建四项 Secret：

```text
PREFIX_ANDROID_KEYSTORE_BASE64
PREFIX_ANDROID_KEYSTORE_PASSWORD
PREFIX_ANDROID_KEY_ALIAS
PREFIX_ANDROID_KEY_PASSWORD
```

其中 Base64 值从签名文件生成。macOS 可安全地直接复制到剪贴板：

```sh
base64 -i /absolute/path/to/upload-keystore.jks | tr -d '\n' | pbcopy
pbpaste | wc -c
```

第二条命令只显示字符数，不能显示密钥；确认非零后，将剪贴板内容粘贴到 `PREFIX_ANDROID_KEYSTORE_BASE64`。其余三项分别来自 `key.properties` 的 `storePassword`、`keyAlias`、`keyPassword`。

## B. 接入新建马甲

### 1. 创建 Android 工程与唯一身份

Flutter 应用必须已有 `android/` 目录。若尚未生成，在应用根目录执行：

```sh
flutter create --platforms=android .
```

设置唯一 Application ID，例如 `com.yourcompany.newapp`，并同步完成应用名、图标和版本号。新应用不得沿用其他马甲的包名或签名。

### 2. 创建独立签名

为新应用生成并妥善备份独立 JKS。下面是示例；请替换别名和保存路径，并将密码保存到密码管理器：

```sh
keytool -genkeypair -v \
  -keystore newapp-upload.jks \
  -alias newapp_upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

签名丢失后无法更新已发布应用。请至少保留离线加密备份和受控密码管理器备份。

### 3. 接入通用工作流

1. 在 [`.github/android-packages.json`](../.github/android-packages.json) 的 `apps` 下新增应用。`secret_prefix` 必须全大写、唯一，例如：

   ```json
   "newapp": {
     "display_name": "New App",
     "path": "apps/newapp",
     "secret_prefix": "NEWAPP",
     "application_id": "com.yourcompany.newapp"
   }
   ```

2. 在 [`.github/workflows/android-package.yml`](../.github/workflows/android-package.yml) 的 `workflow_dispatch.inputs.app.options` 中添加 `newapp`，使它出现在 Actions 下拉菜单中。

3. 在新应用的 `android/app/build.gradle.kts` 接入 `android/key.properties` 签名读取逻辑。可复制仓库中任一已接入项目的相同区块，例如 [Jufu 的 Android 构建配置](../apps/photo/android/app/build.gradle.kts)。`key.properties` 和 `release-keystore.jks` 已被 `.gitignore` 排除，工作流会在 runner 上临时生成它们。

4. 创建 `NEWAPP_ANDROID_*` 四项 Repository Secrets，字段含义与已有马甲完全相同。

5. 提交、推送后，在 **Actions → Android Package** 中选择 `newapp`，先构建 APK 验证安装和签名，再构建 AAB。

## 打包与验收

在 **Actions → Android Package → Run workflow** 中：

- `apk`：用于手机下载、安装和验收。
- `appbundle`：生成 `.aab`，用于上传 Google Play；不能直接安装。
- `sign_release=true`：默认且用于正式签名。任一 Secret 缺失会立即失败，不会静默使用 debug key。
- `sign_release=false`：只用于内部构建验证，不能上传商店。

成功运行后，在该次 Actions 运行的 **Summary → Artifacts** 下载 ZIP；解压即可取得 APK/AAB。Artifact 默认保留 30 天。

发布前至少核对：

1. AAB 签名与该应用历史构建或预期 JKS 一致；
2. Application ID、versionName、versionCode 与 Play Console 目标应用一致；
3. 在实体 Android 设备安装 APK 并完成核心功能冒烟；
4. 新应用先上传 Play Internal testing，确认处理结果后再扩大发布范围。

## 常见问题

| 现象 | 原因与处理 |
| --- | --- |
| `base64: invalid input` | `*_ANDROID_KEYSTORE_BASE64` 不是纯 Base64。重新从 JKS 生成并粘贴，不要带引号、文件名或 `data:` 前缀。 |
| `Keystore file ... not found` | 工作流或 Gradle 的 keystore 路径不一致。通用工作流写入 `android/app/release-keystore.jks`，`key.properties` 的 `storeFile` 必须是 `release-keystore.jks`。 |
| 缺少 Secret | 检查所选 app 的 `secret_prefix`，并创建对应四项 `PREFIX_ANDROID_*` Repository Secrets。 |
| Google Play 拒绝更新签名 | 使用了错误 JKS，或该应用启用了 Play App Signing 但上传证书不匹配。停止上传，按 Play Console 的证书信息核对。 |
| Actions 中没有新应用 | 同时检查 `android-packages.json` 和 workflow 的 app 下拉 `options`，并确认修改已推送到所选分支。 |

## 当前已接入应用

现有可选应用与 Secret 前缀见 [Android 打包说明](android-packaging.md)。`PhotoReport` 与 `TripCost` 当前没有 Android 工程，需要先完成“新建马甲”的 Android 平台步骤后再接入。
